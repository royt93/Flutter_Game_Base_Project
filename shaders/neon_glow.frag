#version 460 core
#include <flutter/runtime_effect.glsl>

// Aura neon động cho bàn chơi (Wave 10). Vẽ 1 lần/frame dưới lớp gem.
// uColor.rgb = tông neon theo thế giới; uColor.a = cường độ tổng.
uniform vec2 uResolution;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec2 p = uv - 0.5;
  float d = length(p);

  // Vầng sáng toả tâm + gợn sóng nhịp
  float wave = 0.5 + 0.5 * sin(uTime * 1.4 + d * 16.0);
  float glow = smoothstep(0.62, 0.0, d) * (0.45 + 0.55 * wave);

  // 2 quầng trôi nhẹ tạo chiều sâu plasma
  vec2 a = p - vec2(0.24 * sin(uTime * 0.7), 0.20 * cos(uTime * 0.9));
  vec2 b = p + vec2(0.20 * cos(uTime * 0.6), 0.24 * sin(uTime * 0.8));
  glow += 0.12 / (length(a) * 6.0 + 0.45);
  glow += 0.12 / (length(b) * 6.0 + 0.45);

  glow = clamp(glow, 0.0, 1.0);
  float alpha = clamp(glow * uColor.a, 0.0, 1.0);
  vec3 col = uColor.rgb * glow;
  // premultiplied alpha (Flutter mong đợi)
  fragColor = vec4(col * alpha, alpha);
}
