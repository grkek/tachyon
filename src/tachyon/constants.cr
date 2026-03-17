module Tachyon
  module Constants
    VERTEX_SHADER_SOURCE = <<-GLSL
      #version 410 core

      layout(location = 0) in vec3 aPosition;
      layout(location = 1) in vec3 aNormal;
      layout(location = 2) in vec2 aTexCoord;

      uniform mat4 uModel;
      uniform mat4 uView;
      uniform mat4 uProjection;
      uniform mat4 uNormalMatrix;
      uniform mat4 uLightSpaceMatrix;

      out vec3 vFragPos;
      out vec3 vNormal;
      out vec2 vTexCoord;
      out vec4 vFragPosLightSpace;

      void main() {
        vec4 worldPos = uModel * vec4(aPosition, 1.0);
        vFragPos = worldPos.xyz;
        vNormal = mat3(uNormalMatrix) * aNormal;
        vTexCoord = aTexCoord;
        vFragPosLightSpace = uLightSpaceMatrix * worldPos;
        gl_Position = uProjection * uView * worldPos;
      }
    GLSL

    FRAGMENT_SHADER_SOURCE = <<-GLSL
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

      // Shadow map
      uniform sampler2D uShadowMap;
      uniform int uHasShadowMap;
      uniform mat4 uLightSpaceMatrix;

      in vec3 vFragPos;
      in vec3 vNormal;
      in vec2 vTexCoord;
      in vec4 vFragPosLightSpace;

      out vec4 fragColor;

      // PBR functions (Cook-Torrance BRDF)

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

      // Per-light radiance

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

        // Cook-Torrance BRDF
        float NDF = DistributionGGX(N, H, roughness);
        float G = GeometrySmith(N, V, L, roughness);
        vec3 F = FresnelSchlick(max(dot(H, V), 0.0), F0);

        vec3 numerator = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        vec3 specular = numerator / denominator;

        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= 1.0 - metallic; // Metals have no diffuse

        float NdotL = max(dot(N, L), 0.0);
        return (kD * albedo / PI + specular) * radiance * NdotL;
      }

      void main() {
        // Sample textures or use uniform values
        vec3 albedo = uMaterial.albedo;
        if (uMaterial.hasAlbedoMap != 0) {
          albedo = texture(uAlbedoMap, vTexCoord).rgb;
        }

        float metallic = uMaterial.metallic;
        float roughness = uMaterial.roughness;
        if (uMaterial.hasMetallicRoughnessMap != 0) {
          vec2 mr = texture(uMetallicRoughnessMap, vTexCoord).bg; // glTF: B=metallic, G=roughness
          metallic = mr.x;
          roughness = mr.y;
        }

        float ao = uMaterial.ao;
        if (uMaterial.hasAoMap != 0) {
          ao = texture(uAoMap, vTexCoord).r;
        }

        vec3 emissive = uMaterial.emissive;
        if (uMaterial.hasEmissiveMap != 0) {
          emissive = texture(uEmissiveMap, vTexCoord).rgb;
        }

        vec3 N = normalize(vNormal);
        // TODO: normal map TBN transform when hasNormalMap

        vec3 V = normalize(uViewPos - vFragPos);

        // F0: reflectance at normal incidence
        // Dielectrics: 0.04, metals: albedo color
        vec3 F0 = vec3(0.04);
        F0 = mix(F0, albedo, metallic);

        // Accumulate light contributions
        vec3 Lo = vec3(0.0);
        for (int i = 0; i < uLightCount && i < MAX_LIGHTS; i++) {
          vec3 lightContrib = CalcLight(uLights[i], N, V, F0, albedo, metallic, roughness);

          // Apply shadow to first directional light only
          if (i == 0 && uLights[i].type == LIGHT_DIRECTIONAL && uHasShadowMap != 0) {
            float shadow = ShadowCalculation(vFragPosLightSpace);
            lightContrib *= shadow;
          }

          Lo += lightContrib;
        }

        // Ambient (simple IBL approximation)
        vec3 ambient = uAmbientColor * albedo * ao;

        vec3 color = ambient + Lo + emissive * uMaterial.emissiveStrength;

        fragColor = vec4(color, uMaterial.opacity);
      }
    GLSL

    SHADOW_DEPTH_VERTEX = <<-GLSL
        #version 410 core
        layout(location = 0) in vec3 aPosition;

        uniform mat4 uLightSpaceMatrix;
        uniform mat4 uModel;

        void main() {
          gl_Position = uLightSpaceMatrix * uModel * vec4(aPosition, 1.0);
        }
      GLSL

    SHADOW_DEPTH_FRAGMENT = <<-GLSL
        #version 410 core
        void main() {
          // Depth is written automatically
        }
      GLSL

    SKYBOX_VERTEX = <<-GLSL
        #version 410 core
        layout(location = 0) in vec3 aPosition;

        uniform mat4 uView;
        uniform mat4 uProjection;

        out vec3 vTexCoord;

        void main() {
          vTexCoord = aPosition;
          // Remove translation from view matrix
          mat4 viewNoTranslation = mat4(mat3(uView));
          vec4 pos = uProjection * viewNoTranslation * vec4(aPosition, 1.0);
          // Set z = w so depth is always 1.0 (farthest)
          gl_Position = pos.xyww;
        }
      GLSL

    SKYBOX_FRAGMENT = <<-GLSL
        #version 410 core

        in vec3 vTexCoord;
        out vec4 fragColor;

        uniform samplerCube uSkybox;

        void main() {
          fragColor = texture(uSkybox, vTexCoord);
        }
      GLSL

    QUAD_VERTICES = StaticArray[
      -1.0f32, -1.0f32, 0.0f32, 0.0f32,
      1.0f32, -1.0f32, 1.0f32, 0.0f32,
      1.0f32, 1.0f32, 1.0f32, 1.0f32,
      -1.0f32, -1.0f32, 0.0f32, 0.0f32,
      1.0f32, 1.0f32, 1.0f32, 1.0f32,
      -1.0f32, 1.0f32, 0.0f32, 1.0f32,
    ]

    QUAD_VERT = <<-GLSL
        #version 410 core
        layout(location = 0) in vec2 aPosition;
        layout(location = 1) in vec2 aTexCoord;
        out vec2 vTexCoord;
        void main() {
          vTexCoord = aTexCoord;
          gl_Position = vec4(aPosition, 0.0, 1.0);
        }
      GLSL

    BRIGHT_FRAG = <<-GLSL
        #version 410 core
        in vec2 vTexCoord;
        out vec4 fragColor;
        uniform sampler2D uScene;
        uniform float uThreshold;
        void main() {
          vec3 color = texture(uScene, vTexCoord).rgb;
          float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
          fragColor = brightness > uThreshold ? vec4(color, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);
        }
      GLSL

    BLUR_FRAG = <<-GLSL
        #version 410 core
        in vec2 vTexCoord;
        out vec4 fragColor;
        uniform sampler2D uImage;
        uniform int uHorizontal;
        void main() {
          float weights[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
          vec2 texOffset = 1.0 / textureSize(uImage, 0);
          vec3 result = texture(uImage, vTexCoord).rgb * weights[0];
          if (uHorizontal != 0) {
            for (int i = 1; i < 5; ++i) {
              result += texture(uImage, vTexCoord + vec2(texOffset.x * float(i), 0.0)).rgb * weights[i];
              result += texture(uImage, vTexCoord - vec2(texOffset.x * float(i), 0.0)).rgb * weights[i];
            }
          } else {
            for (int i = 1; i < 5; ++i) {
              result += texture(uImage, vTexCoord + vec2(0.0, texOffset.y * float(i))).rgb * weights[i];
              result += texture(uImage, vTexCoord - vec2(0.0, texOffset.y * float(i))).rgb * weights[i];
            }
          }
          fragColor = vec4(result, 1.0);
        }
      GLSL

    COMPOSITE_FRAG = <<-GLSL
        #version 410 core
        in vec2 vTexCoord;
        out vec4 fragColor;
        uniform sampler2D uScene;
        uniform sampler2D uBloom;
        uniform float uBloomIntensity;
        void main() {
          vec3 scene = texture(uScene, vTexCoord).rgb;
          vec3 bloom = texture(uBloom, vTexCoord).rgb;
          fragColor = vec4(scene + bloom * uBloomIntensity, 1.0);
        }
      GLSL

    SSAO_FRAG = <<-GLSL
        #version 410 core
        in vec2 vTexCoord;
        out float fragColor;

        uniform sampler2D uDepth;
        uniform sampler2D uNoise;
        uniform vec3 uSamples[32];
        uniform mat4 uProjection;
        uniform mat4 uView;
        uniform vec2 uNoiseScale;
        uniform float uRadius;
        uniform float uBias;

        float linearizeDepth(float d, float near, float far) {
          return near * far / (far - d * (far - near));
        }

        void main() {
          float depth = texture(uDepth, vTexCoord).r;
          if (depth >= 1.0) { fragColor = 1.0; return; }

          vec3 noise = texture(uNoise, vTexCoord * uNoiseScale).xyz;

          float linearDepth = linearizeDepth(depth, 0.1, 100.0);
          vec3 fragPos = vec3(vTexCoord * 2.0 - 1.0, depth);

          float occlusion = 0.0;
          for (int i = 0; i < 32; ++i) {
            vec3 samplePos = fragPos + uSamples[i] * uRadius;
            vec4 offset = uProjection * vec4(samplePos, 1.0);
            offset.xy = offset.xy / offset.w * 0.5 + 0.5;
            float sampleDepth = texture(uDepth, offset.xy).r;
            float rangeCheck = smoothstep(0.0, 1.0, uRadius / abs(depth - sampleDepth));
            occlusion += (sampleDepth >= depth + uBias ? 0.0 : 1.0) * rangeCheck;
          }
          fragColor = 1.0 - (occlusion / 32.0);
        }
      GLSL

    SSAO_BLUR_FRAG = <<-GLSL
        #version 410 core
        in vec2 vTexCoord;
        out float fragColor;
        uniform sampler2D uSSAO;
        void main() {
          vec2 texelSize = 1.0 / vec2(textureSize(uSSAO, 0));
          float result = 0.0;
          for (int x = -2; x <= 2; ++x) {
            for (int y = -2; y <= 2; ++y) {
              result += texture(uSSAO, vTexCoord + vec2(float(x), float(y)) * texelSize).r;
            }
          }
          fragColor = result / 25.0;
        }
      GLSL

    GUI_VERTEX_SHADER = <<-GLSL
      #version 410 core
      layout(location = 0) in vec2 aPosition;
      layout(location = 1) in vec2 aTexCoord;

      uniform mat4 uProjection;
      uniform vec2 uPosition;
      uniform vec2 uSize;

      out vec2 vTexCoord;

      void main() {
        vec2 pos = aPosition * uSize + uPosition;
        gl_Position = uProjection * vec4(pos, 0.0, 1.0);
        vTexCoord = aTexCoord;
      }
    GLSL

    GUI_FRAGMENT_SHADER = <<-GLSL
      #version 410 core
      in vec2 vTexCoord;
      out vec4 fragColor;

      uniform sampler2D uTexture;
      uniform vec4 uColor;
      uniform int uHasTexture;
      uniform int uIsText;

      void main() {
        if (uIsText != 0) {
          float alpha = texture(uTexture, vTexCoord).r;
          fragColor = vec4(uColor.rgb, uColor.a * alpha);
        } else if (uHasTexture != 0) {
          fragColor = texture(uTexture, vTexCoord) * uColor;
        } else {
          fragColor = uColor;
        }
      }
    GLSL
  end
end
