#version 460 core
#include <flutter/runtime_effect.glsl>

// I16: dải aurora chuyển sắc phủ lên nền, chỉ dùng ở world cuối (khó nhất).
// uColor = tông màu world (indigo) làm gốc, lệch hue theo dải + thời gian.
uniform vec2 uResolution;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

vec3 hueShift(vec3 col, float amt) {
  const vec3 k = vec3(0.57735, 0.57735, 0.57735);
  float cosA = cos(amt);
  return col * cosA + cross(k, col) * sin(amt) + k * dot(k, col) * (1.0 - cosA);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;

  float bands = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float wave = sin(uv.x * (3.0 + fi * 1.5) + uTime * (0.3 + fi * 0.15) + fi * 2.1);
    float band = 0.42 + fi * 0.14 + wave * 0.12;
    bands += smoothstep(0.10, 0.0, abs(uv.y - band)) * (0.55 - fi * 0.12);
  }

  vec3 col = hueShift(uColor.rgb, bands * 2.4 + uTime * 0.15);
  float alpha = clamp(bands * uColor.a, 0.0, 0.85);
  // premultiplied alpha (Flutter mong đợi)
  fragColor = vec4(col * alpha, alpha);
}
