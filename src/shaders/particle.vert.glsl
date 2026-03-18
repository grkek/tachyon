#version 410 core

layout(location = 0) in vec2 aQuadPos;
layout(location = 1) in vec2 aTexCoord;
layout(location = 2) in vec3 aInstancePos;
layout(location = 3) in float aInstanceSize;
layout(location = 4) in vec4 aInstanceColor;

uniform mat4 uView;
uniform mat4 uProjection;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

out vec2 vTexCoord;
out vec4 vColor;

void main() {
  vec3 worldPos = aInstancePos
    + uCameraRight * aQuadPos.x * aInstanceSize
    + uCameraUp * aQuadPos.y * aInstanceSize;
  gl_Position = uProjection * uView * vec4(worldPos, 1.0);
  vTexCoord = aTexCoord;
  vColor = aInstanceColor;
}
