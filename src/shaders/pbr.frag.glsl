#version 410 core

const float PI = 3.14159265359;
const int MAX_LIGHTS = 8;

// Light types
const int LIGHT_DIRECTIONAL = 0;
const int LIGHT_POINT = 1;
const int LIGHT_SPOT = 2;

struct Light {
  int type;
  vec3 color;
  float intensity;
  vec3 position;
  vec3 direction;
  float range;
  float innerCutoff;
  float outerCutoff;
};

struct Material {
  vec3 albedo;
  float metallic;
  float roughness;
  float ao;
  vec3 emissive;
  float emissiveStrength;
  float opacity;
  int hasAlbedoMap;
  int hasNormalMap;
  int hasMetallicRoughnessMap;
  int hasAoMap;
  int hasEmissiveMap;
};

uniform Material uMaterial;
uniform Light uLights[MAX_LIGHTS];
uniform int uLightCount;
uniform vec3 uViewPos;
uniform vec3 uAmbientColor;

// Texture samplers
uniform sampler2D uAlbedoMap;
uniform sampler2D uNormalMap;
uniform sampler2D uMetallicRoughnessMap;
uniform sampler2D uAoMap;
uniform sampler2D uEmissiveMap;
uniform vec2 uTextureScale;

// Shadow map
uniform sampler2D uShadowMap;
uniform int uHasShadowMap;
uniform mat4 uLightSpaceMatrix;

// Fog
uniform int uFogEnabled;
uniform vec3 uFogColor;
uniform float uFogNear;
uniform float uFogFar;
uniform float uFogDensity;
uniform int uFogMode; // 0 = linear, 1 = exponential, 2 = exponential squared

// SSAO
uniform sampler2D uSSAOMap;
uniform int uHasSSAO;

// IBL
uniform samplerCube uIrradianceMap;
uniform samplerCube uPrefilterMap;
uniform sampler2D uBRDFLUT;
uniform int uHasIBL;
uniform float uIBLIntensity;

in vec3 vFragPos;
in vec3 vNormal;
in vec2 vTexCoord;
in vec4 vFragPosLightSpace;

out vec4 fragColor;

// Normal Distribution Function (GGX/Trowbridge-Reitz)
float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;
  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = PI * denom * denom;
  return a2 / max(denom, 0.0001);
}

// Geometry Function (Smith's Schlick-GGX)
float GeometrySchlickGGX(float NdotV, float roughness) {
  float r = (roughness + 1.0);
  float k = (r * r) / 8.0;
  return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);
  return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
}

// Fresnel (Schlick approximation)
vec3 FresnelSchlick(float cosTheta, vec3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Shadow calculation with PCF
float ShadowCalculation(vec4 fragPosLightSpace) {
  vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
  projCoords = projCoords * 0.5 + 0.5;

  if (projCoords.z > 1.0) return 1.0;

  float shadow = 0.0;
  vec2 texelSize = 1.0 / textureSize(uShadowMap, 0);
  float currentDepth = projCoords.z;
  float bias = 0.003;

  for (int x = -2; x <= 2; ++x) {
    for (int y = -2; y <= 2; ++y) {
      float closestDepth = texture(uShadowMap, projCoords.xy + vec2(x, y) * texelSize).r;
      shadow += currentDepth - bias > closestDepth ? 0.0 : 1.0;
    }
  }
  return shadow / 25.0;
}

// Per-light radiance using Cook-Torrance BRDF
vec3 CalcLight(Light light, vec3 N, vec3 V, vec3 F0, vec3 albedo, float metallic, float roughness) {
  vec3 L;
  float attenuation = 1.0;

  if (light.type == LIGHT_DIRECTIONAL) {
    L = normalize(-light.direction);
  } else {
    L = normalize(light.position - vFragPos);
    float dist = length(light.position - vFragPos);
    // Smooth attenuation with range
    float falloff = clamp(1.0 - pow(dist / light.range, 4.0), 0.0, 1.0);
    attenuation = (falloff * falloff) / (dist * dist + 1.0);

    if (light.type == LIGHT_SPOT) {
      float theta = dot(L, normalize(-light.direction));
      float epsilon = light.innerCutoff - light.outerCutoff;
      float spotIntensity = clamp((theta - light.outerCutoff) / epsilon, 0.0, 1.0);
      attenuation *= spotIntensity;
    }
  }

  vec3 H = normalize(V + L);
  vec3 radiance = light.color * light.intensity * attenuation;

  float NDF = DistributionGGX(N, H, roughness);
  float G = GeometrySmith(N, V, L, roughness);
  vec3 F = FresnelSchlick(max(dot(H, V), 0.0), F0);

  vec3 numerator = NDF * G * F;
  float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
  vec3 specular = numerator / denominator;

  vec3 kS = F;
  vec3 kD = vec3(1.0) - kS;
  kD *= 1.0 - metallic;

  float NdotL = max(dot(N, L), 0.0);
  return (kD * albedo / PI + specular) * radiance * NdotL;
}

void main() {
  vec2 scaledUV = vTexCoord * uTextureScale;

  // Sample material properties
  vec3 albedo = uMaterial.albedo;
  if (uMaterial.hasAlbedoMap != 0) {
    albedo = texture(uAlbedoMap, scaledUV).rgb;
  }

  float metallic = uMaterial.metallic;
  float roughness = uMaterial.roughness;
  if (uMaterial.hasMetallicRoughnessMap != 0) {
    vec2 mr = texture(uMetallicRoughnessMap, scaledUV).bg;
    metallic = mr.x;
    roughness = mr.y;
  }

  float ao = uMaterial.ao;
  if (uMaterial.hasAoMap != 0) {
    ao = texture(uAoMap, scaledUV).r;
  }

  vec3 emissive = uMaterial.emissive;
  if (uMaterial.hasEmissiveMap != 0) {
    emissive = texture(uEmissiveMap, scaledUV).rgb;
  }

  // Compute normal (with optional normal mapping)
  vec3 N = normalize(vNormal);
  if (uMaterial.hasNormalMap != 0) {
    vec3 tangentNormal = texture(uNormalMap, scaledUV).rgb * 2.0 - 1.0;
    vec3 Q1 = dFdx(vFragPos);
    vec3 Q2 = dFdy(vFragPos);
    vec2 st1 = dFdx(scaledUV);
    vec2 st2 = dFdy(scaledUV);
    vec3 T = normalize(Q1 * st2.t - Q2 * st1.t);
    vec3 B = normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);
    N = normalize(TBN * tangentNormal);
  }

  vec3 V = normalize(uViewPos - vFragPos);

  // Fresnel reflectance at normal incidence
  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  // Accumulate light contributions
  vec3 Lo = vec3(0.0);
  for (int i = 0; i < uLightCount && i < MAX_LIGHTS; i++) {
    vec3 lightContrib = CalcLight(uLights[i], N, V, F0, albedo, metallic, roughness);

    // Apply shadow only to the primary directional light
    if (i == 0 && uLights[i].type == LIGHT_DIRECTIONAL && uHasShadowMap != 0) {
      float shadow = ShadowCalculation(vFragPosLightSpace);
      lightContrib *= shadow;
    }

    Lo += lightContrib;
  }

  // Ambient lighting (IBL or flat)
  vec3 ambient;

  if (uHasIBL != 0) {
    vec3 F = FresnelSchlick(max(dot(N, V), 0.0), F0);
    vec3 kS = F;
    vec3 kD = (1.0 - kS) * (1.0 - metallic);
    vec3 irradiance = texture(uIrradianceMap, N).rgb * uIBLIntensity;
    vec3 diffuse = irradiance * albedo;
    const float MAX_REFLECTION_LOD = 4.0;
    vec3 R = reflect(-V, N);
    vec3 prefilteredColor = textureLod(uPrefilterMap, R, roughness * MAX_REFLECTION_LOD).rgb * uIBLIntensity;
    vec2 brdf = texture(uBRDFLUT, vec2(max(dot(N, V), 0.0), roughness)).rg;
    vec3 specular = prefilteredColor * (F * brdf.x + brdf.y);
    ambient = (kD * diffuse + specular) * ao;
  } else {
    ambient = uAmbientColor * albedo * ao;
  }

  // Apply SSAO
  if (uHasSSAO != 0) {
    float ssaoFactor = texture(uSSAOMap, gl_FragCoord.xy / vec2(textureSize(uSSAOMap, 0))).r;
    ambient *= ssaoFactor;
  }

  vec3 color = ambient + Lo + emissive * uMaterial.emissiveStrength;

  // Distance fog
  if (uFogEnabled != 0) {
    float fogDistance = length(uViewPos - vFragPos);
    float fogFactor = 1.0;
    if (uFogMode == 0) {
      fogFactor = clamp((uFogFar - fogDistance) / (uFogFar - uFogNear), 0.0, 1.0);
    } else if (uFogMode == 1) {
      fogFactor = exp(-uFogDensity * fogDistance);
    } else {
      float d = uFogDensity * fogDistance;
      fogFactor = exp(-d * d);
    }
    color = mix(uFogColor, color, fogFactor);
  }

  fragColor = vec4(color, uMaterial.opacity);
}
