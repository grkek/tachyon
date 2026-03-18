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
