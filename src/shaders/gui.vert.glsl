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
