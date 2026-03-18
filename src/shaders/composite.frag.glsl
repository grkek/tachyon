#version 410 core

in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform float uBloomIntensity;

vec3 ACESFilm(vec3 x) {
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
  vec3 scene = texture(uScene, vTexCoord).rgb;
  vec3 bloom = texture(uBloom, vTexCoord).rgb;
  vec3 hdr = scene + bloom * uBloomIntensity;
  vec3 mapped = ACESFilm(hdr);
  mapped = pow(mapped, vec3(1.0 / 2.2));
  fragColor = vec4(mapped, 1.0);
}
