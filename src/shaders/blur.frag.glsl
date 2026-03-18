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
