---
id: ENH-101
title: Pulsing / Radar BadgeDot — Chấm thông báo nhịp tim & sóng lan toả
type: enhancement
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
BadgeDot hiện tại chỉ là chấm đỏ tĩnh, khó thu hút sự chú ý của người chơi vào các nút sự kiện, quà tặng chưa nhận.

## Đề xuất phạm vi
Nâng cấp BadgeDot với tuỳ chọn pulse: true (hiệu ứng nhịp đập tim scale 1.0->1.25) hoặc radar: true (vòng sóng hào quang mờ dần toả ra ngoài).

## Yêu cầu kiểm thử
- [x] **Unit/widget test**: Pulse scale, radar painter, Reduced Motion static mode, flags off stop ticker, default static behavior, semantics unchanged.
- [x] **Showcase test**: Animated BadgeDot mounts and ticks without framework errors.
- [x] **TECNO integration smoke**: TECNO KJ7 (115333744A005844) sampled the pulsing BadgeDot transform over 1.5s and saw peak scale above 1.2; no simulator.
- [x] **Host validation**: root 2989/example 250 suites, analyzers and all quality gates pass.

## Hiệu năng & lifecycle
- [x] Uses one repeating 1500ms controller only when pulse/radar enabled and motion allowed; RepaintBoundary isolates badge; dispose stops ticker.
- [ ] 60 FPS benchmark: not measured separately for badge animation.
