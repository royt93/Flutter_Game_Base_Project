---
id: FEAT-112
title: ScratchCard — Thẻ cào may mắn tương tác ngón tay lộ phần thưởng
type: feature
priority: P1
effort: L
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Minigame thẻ cào cực kỳ hấp dẫn cho các sự kiện may mắn, người chơi dùng ngón tay cào lớp nhũ để dần lộ ra giải thưởng bên dưới.

## Đề xuất phạm vi
Widget ScratchCard nhận background widget (quà) và cover widget (lớp nhũ bạc/vàng), cho phép cào bằng cử chỉ ngón tay, tính toán % đã cào và tự động mở toang khi đạt >60%.

## Kiểm thử
- [x] **Unit test**: Grid segment coverage, duplicate cells count once, bounds, strict `> 60%` threshold.
- [x] **Widget test**: Multi-lane drag, `BlendMode.clear` cover, reveal callback once, semantic reveal action.
- [x] **Showcase test**: Scratch reward state updates only after reveal.
- [x] **Physical integration**: Four fast continuous finger-scratch lanes on Samsung S24 Ultra (SM-S928B) reached reveal without gaps/framework errors; no simulator used.
- [x] **Host validation**: root 2990/example 250 suites, analyzers and quality gates pass.

## Hiệu năng & resource
- [x] Fixed grid size, bounded segment candidate cells; pointer samples interpolate segment coverage; cover isolated by clipped `saveLayer` + `BlendMode.clear`.
- [x] **TECNO KJ7 benchmark telemetry (154 frames)**: p50=31.26ms (~32 FPS), p95=63.00ms, p99=125.59ms, slow=74.0% (>16.67ms), jank=74 (>33.33ms). On this entry-level GPU, continuous saveLayer canvas clearing runs at ~30-35 FPS during fast scratching; not sustained 60 FPS.
