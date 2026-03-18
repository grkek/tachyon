#version 410 core

in vec2 vTexCoord;
in vec4 vColor;
out vec4 fragColor;

uniform sampler2D uTexture;

void main() {
  vec4 texColor = texture(uTexture, vTexCoord);
  fragColor = texColor * vColor;
  if (fragColor.a < 0.01) discard;
}
