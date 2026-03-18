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
