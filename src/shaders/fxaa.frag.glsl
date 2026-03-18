#version 410 core
in vec2 vTexCoord;
out vec4 fragColor;
uniform sampler2D uScene;
uniform vec2 uInverseScreenSize;

float luminance(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

void main() {
  float FXAA_SPAN_MAX = 8.0;
  float FXAA_REDUCE_MUL = 1.0 / 8.0;
  float FXAA_REDUCE_MIN = 1.0 / 128.0;

  vec2 texOffset = uInverseScreenSize;

  vec3 rgbNW = texture(uScene, vTexCoord + vec2(-1.0, -1.0) * texOffset).rgb;
  vec3 rgbNE = texture(uScene, vTexCoord + vec2(1.0, -1.0) * texOffset).rgb;
  vec3 rgbSW = texture(uScene, vTexCoord + vec2(-1.0, 1.0) * texOffset).rgb;
  vec3 rgbSE = texture(uScene, vTexCoord + vec2(1.0, 1.0) * texOffset).rgb;
  vec3 rgbM  = texture(uScene, vTexCoord).rgb;

  float lumNW = luminance(rgbNW);
  float lumNE = luminance(rgbNE);
  float lumSW = luminance(rgbSW);
  float lumSE = luminance(rgbSE);
  float lumM  = luminance(rgbM);

  float lumMin = min(lumM, min(min(lumNW, lumNE), min(lumSW, lumSE)));
  float lumMax = max(lumM, max(max(lumNW, lumNE), max(lumSW, lumSE)));

  vec2 dir;
  dir.x = -((lumNW + lumNE) - (lumSW + lumSE));
  dir.y = ((lumNW + lumSW) - (lumNE + lumSE));

  float dirReduce = max((lumNW + lumNE + lumSW + lumSE) * 0.25 * FXAA_REDUCE_MUL, FXAA_REDUCE_MIN);
  float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
  dir = min(vec2(FXAA_SPAN_MAX), max(vec2(-FXAA_SPAN_MAX), dir * rcpDirMin)) * texOffset;

  vec3 rgbA = 0.5 * (
    texture(uScene, vTexCoord + dir * (1.0 / 3.0 - 0.5)).rgb +
    texture(uScene, vTexCoord + dir * (2.0 / 3.0 - 0.5)).rgb);

  vec3 rgbB = rgbA * 0.5 + 0.25 * (
    texture(uScene, vTexCoord + dir * -0.5).rgb +
    texture(uScene, vTexCoord + dir * 0.5).rgb);

  float lumB = luminance(rgbB);

  if (lumB < lumMin || lumB > lumMax) {
    fragColor = vec4(rgbA, 1.0);
  } else {
    fragColor = vec4(rgbB, 1.0);
  }
}
