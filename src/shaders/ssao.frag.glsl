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
