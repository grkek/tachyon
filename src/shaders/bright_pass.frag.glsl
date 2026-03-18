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
