#version 410 core

const float PI = 3.14159265359;
const int MAX_LIGHTS = 8;
const int MAX_CASCADES = 4;

const int LIGHT_DIRECTIONAL = 0;
const int LIGHT_POINT = 1;
const int LIGHT_SPOT = 2;

struct LightData {
  int type;
  float intensity;
  float range;
  float innerCutoff;
  vec3 color;       float _pad0;
  vec3 position;    float _pad1;
  vec3 direction;   float _pad2;
  float outerCutoff;
  float _pad3;
  float _pad4;
  float _pad5;
};

layout(std140) uniform FrameData {
  mat4 uView;
  mat4 uProjection;
  vec3 uViewPos;      float _fp0;
  vec3 uAmbientColor; float _fp1;

  int  uFogEnabled;
  int  uFogMode;
  float uFogNear;
  float uFogFar;
  vec3 uFogColor;     float _fp2;
  float uFogDensity;
  float _fp3;
  float _fp4;
  float _fp5;

  int  uHasShadowMap;
  int  uCascadeCount;
  float _fp6;
  float _fp7;
  mat4 uCascadeMatrix[MAX_CASCADES];
  vec4 uCascadeSplits;

  int  uLightCount;
  float _fp8;
  float _fp9;
  float _fp10;
  LightData uLights[MAX_LIGHTS];
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

uniform sampler2D uAlbedoMap;
uniform sampler2D uNormalMap;
uniform sampler2D uMetallicRoughnessMap;
uniform sampler2D uAoMap;
uniform sampler2D uEmissiveMap;
uniform vec2 uTextureScale;

uniform mat4 uModel;
uniform mat4 uNormalMatrix;

uniform sampler2D uShadowMap0;
uniform sampler2D uShadowMap1;
uniform sampler2D uShadowMap2;
uniform sampler2D uShadowMap3;

uniform sampler2D uShadowMap;
uniform mat4 uLightSpaceMatrix;

uniform sampler2D uSSAOMap;
uniform int uHasSSAO;

uniform samplerCube uIrradianceMap;
uniform samplerCube uPrefilterMap;
uniform sampler2D uBRDFLUT;
uniform int uHasIBL;
uniform float uIBLIntensity;

in vec3 vFragPos;
in vec3 vNormal;
in vec2 vTexCoord;
in float vViewDepth;

out vec4 fragColor;

// PBR BRDF

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;
  float denom = NdotH2 * (a2 - 1.0) + 1.0;
  denom = PI * denom * denom;
  return a2 / max(denom, 0.0001);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
  float r = roughness + 1.0;
  float k = (r * r) / 8.0;
  return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);
  return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
}

vec3 FresnelSchlick(float cosTheta, vec3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Cascaded Shadow Mapping

float SampleShadowPCF(sampler2D shadowMap, vec3 projCoords, float bias) {
  float currentDepth = projCoords.z;
  float shadow = 0.0;
  vec2 texelSize = 1.0 / textureSize(shadowMap, 0);

  // 3x3 PCF kernel
  for (int x = -1; x <= 1; ++x) {
    for (int y = -1; y <= 1; ++y) {
      float sampleDepth = texture(shadowMap, projCoords.xy + vec2(x, y) * texelSize).r;
      shadow += (currentDepth - bias) > sampleDepth ? 0.0 : 1.0;
    }
  }
  return shadow / 9.0;
}

float SampleCascade(int cascade, vec3 fragPos) {
  vec4 lightSpacePos = uCascadeMatrix[cascade] * vec4(fragPos, 1.0);
  vec3 projCoords = lightSpacePos.xyz / lightSpacePos.w;
  projCoords = projCoords * 0.5 + 0.5;

  if (projCoords.z > 1.0) return 1.0;
  if (projCoords.x < 0.0 || projCoords.x > 1.0 ||
      projCoords.y < 0.0 || projCoords.y > 1.0) return 1.0;

  // No depth bias here — polygon offset in the shadow pass handles acne
  float bias = 0.0001;

  if      (cascade == 0) return SampleShadowPCF(uShadowMap0, projCoords, bias);
  else if (cascade == 1) return SampleShadowPCF(uShadowMap1, projCoords, bias);
  else if (cascade == 2) return SampleShadowPCF(uShadowMap2, projCoords, bias);
  else                   return SampleShadowPCF(uShadowMap3, projCoords, bias);
}

float CascadedShadow(vec3 fragPos) {
  if (uCascadeCount <= 0) {
    vec4 lsp = uLightSpaceMatrix * vec4(fragPos, 1.0);
    vec3 pc = lsp.xyz / lsp.w * 0.5 + 0.5;
    if (pc.z > 1.0) return 1.0;
    return SampleShadowPCF(uShadowMap, pc, 0.0);
  }

  int cascade = uCascadeCount - 1;
  for (int i = 0; i < uCascadeCount; i++) {
    if (vViewDepth < uCascadeSplits[i]) {
      cascade = i;
      break;
    }
  }

  float shadow = SampleCascade(cascade, fragPos);

  float splitDist = uCascadeSplits[cascade];
  float prevSplit = cascade > 0 ? uCascadeSplits[cascade - 1] : 0.0;
  float range = splitDist - prevSplit;
  float blendRegion = range * 0.15;
  float distToEdge = splitDist - vViewDepth;

  if (distToEdge < blendRegion && cascade < uCascadeCount - 1) {
    float t = distToEdge / blendRegion;
    float nextShadow = SampleCascade(cascade + 1, fragPos);
    shadow = mix(nextShadow, shadow, t);
  }

  float maxDist = uCascadeSplits[uCascadeCount - 1];
  float fadeStart = maxDist * 0.75;
  if (vViewDepth > fadeStart) {
    float fade = clamp((maxDist - vViewDepth) / (maxDist - fadeStart), 0.0, 1.0);
    shadow = mix(1.0, shadow, fade);
  }

  return shadow;
}

// Lighting

vec3 CalcLight(int index, vec3 N, vec3 V, vec3 F0, vec3 albedo, float metallic, float roughness) {
  vec3 L;
  float attenuation = 1.0;

  if (uLights[index].type == LIGHT_DIRECTIONAL) {
    L = normalize(-uLights[index].direction);
  } else {
    L = normalize(uLights[index].position - vFragPos);
    float dist = length(uLights[index].position - vFragPos);
    float falloff = clamp(1.0 - pow(dist / uLights[index].range, 4.0), 0.0, 1.0);
    attenuation = (falloff * falloff) / (dist * dist + 1.0);

    if (uLights[index].type == LIGHT_SPOT) {
      float theta = dot(L, normalize(-uLights[index].direction));
      float epsilon = uLights[index].innerCutoff - uLights[index].outerCutoff;
      float spotIntensity = clamp((theta - uLights[index].outerCutoff) / epsilon, 0.0, 1.0);
      attenuation *= spotIntensity;
    }
  }

  vec3 H = normalize(V + L);
  vec3 radiance = uLights[index].color * uLights[index].intensity * attenuation;

  float NDF = DistributionGGX(N, H, roughness);
  float G = GeometrySmith(N, V, L, roughness);
  vec3 F = FresnelSchlick(max(dot(H, V), 0.0), F0);

  vec3 numerator = NDF * G * F;
  float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
  vec3 specular = numerator / denominator;

  vec3 kS = F;
  vec3 kD = (1.0 - kS);
  kD *= 1.0 - metallic;

  float NdotL = max(dot(N, L), 0.0);
  return (kD * albedo / PI + specular) * radiance * NdotL;
}

// Main

void main() {
  vec2 scaledUV = vTexCoord * uTextureScale;

  vec3 albedo = uMaterial.albedo;
  if (uMaterial.hasAlbedoMap != 0)
    albedo = texture(uAlbedoMap, scaledUV).rgb;

  float metallic = uMaterial.metallic;
  float roughness = uMaterial.roughness;
  if (uMaterial.hasMetallicRoughnessMap != 0) {
    vec2 mr = texture(uMetallicRoughnessMap, scaledUV).bg;
    metallic = mr.x;
    roughness = mr.y;
  }

  float ao = uMaterial.ao;
  if (uMaterial.hasAoMap != 0)
    ao = texture(uAoMap, scaledUV).r;

  vec3 emissive = uMaterial.emissive;
  if (uMaterial.hasEmissiveMap != 0)
    emissive = texture(uEmissiveMap, scaledUV).rgb;

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
  vec3 F0 = mix(vec3(0.04), albedo, metallic);

  vec3 Lo = vec3(0.0);
  for (int i = 0; i < uLightCount && i < MAX_LIGHTS; i++) {
    vec3 lightContrib = CalcLight(i, N, V, F0, albedo, metallic, roughness);

    if (i == 0 && uLights[i].type == LIGHT_DIRECTIONAL && uHasShadowMap != 0) {
      lightContrib *= CascadedShadow(vFragPos);
    }

    Lo += lightContrib;
  }

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
    vec3 specIBL = prefilteredColor * (F * brdf.x + brdf.y);
    ambient = (kD * diffuse + specIBL) * ao;
  } else {
    ambient = uAmbientColor * albedo * ao;
  }

  if (uHasSSAO != 0) {
    float ssaoFactor = texture(uSSAOMap, gl_FragCoord.xy / vec2(textureSize(uSSAOMap, 0))).r;
    ambient *= ssaoFactor;
  }

  vec3 color = ambient + Lo + emissive * uMaterial.emissiveStrength;

  if (uFogEnabled != 0) {
    float fogDistance = length(uViewPos - vFragPos);
    float fogFactor;
    if (uFogMode == 0)
      fogFactor = clamp((uFogFar - fogDistance) / (uFogFar - uFogNear), 0.0, 1.0);
    else if (uFogMode == 1)
      fogFactor = exp(-uFogDensity * fogDistance);
    else {
      float d = uFogDensity * fogDistance;
      fogFactor = exp(-d * d);
    }
    color = mix(uFogColor, color, fogFactor);
  }

  fragColor = vec4(color, uMaterial.opacity);
}