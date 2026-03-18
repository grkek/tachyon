#version 410 core

in vec3 vTexCoord;
out vec4 fragColor;

uniform samplerCube uSkybox;

void main() {
  fragColor = texture(uSkybox, vTexCoord);
}
