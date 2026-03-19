#version 410 core

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aTexCoord;

const int MAX_LIGHTS = 8;
const int MAX_CASCADES = 4;

struct LightData {
  int type;
  float intensity;
  float range;
  float innerCutoff;
  vec3 color;       float _pad0;
  vec3 position;    float _pad1;
  vec3 direction;   float _pad2;
  float outerCutoff;
  float _pad3;
  float _pad4;
  float _pad5;
};

layout(std140) uniform FrameData {
  mat4 uView;
  mat4 uProjection;
  vec3 uViewPos;      float _fp0;
  vec3 uAmbientColor; float _fp1;

  int  uFogEnabled;
  int  uFogMode;
  float uFogNear;
  float uFogFar;
  vec3 uFogColor;     float _fp2;
  float uFogDensity;
  float _fp3;
  float _fp4;
  float _fp5;

  int  uHasShadowMap;
  int  uCascadeCount;
  float _fp6;
  float _fp7;
  mat4 uCascadeMatrix[MAX_CASCADES];
  vec4 uCascadeSplits;

  int  uLightCount;
  float _fp8;
  float _fp9;
  float _fp10;
  LightData uLights[MAX_LIGHTS];
};

uniform mat4 uModel;
uniform mat4 uNormalMatrix;

out vec3 vFragPos;
out vec3 vNormal;
out vec2 vTexCoord;
out float vViewDepth;

void main() {
  vec4 worldPos = uModel * vec4(aPosition, 1.0);
  vFragPos = worldPos.xyz;
  vNormal = mat3(uNormalMatrix) * aNormal;
  vTexCoord = aTexCoord;

  vec4 viewPos = uView * worldPos;
  vViewDepth = -viewPos.z;

  gl_Position = uProjection * viewPos;
}