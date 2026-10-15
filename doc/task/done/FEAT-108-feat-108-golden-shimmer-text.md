---
id: FEAT-108
title: GoldenShimmerText — Vệt sáng kim tuyến quét ngang chữ & điểm số lớn
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Điểm số jackpot, kỷ lục mới hoặc danh hiệu huyền thoại cần vệt sáng quét ngang ánh kim lấp lánh để tôn vinh thành tích.

## Đề xuất phạm vi
Widget GoldenShimmerText bọc StrokeText bằng ShaderMask gradient quét sáng tuyến tính từ trái qua phải theo chu kỳ định sẵn.

## Kiểm thử
- [x] **Unit test**: Offset gradient đi từ -1.0 đến 2.0 and clamps outside range.
- [x] **Widget tests**: ShaderMask, semantics, Reduced Motion, TickerMode pause/resume, invalid duration, vertical viewport scroll-out pause and partial scroll-back resume.
- [x] **TECNO integration smoke**: Jackpot shimmer renders and animates on TECNO KJ7 (existing device proof); no simulator.
- [x] **Host validation**: root 2990/example 250 suites, analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] LinearGradient + RepaintBoundary; ticker disposed on unmount and paused by `TickerMode`, Reduced Motion, or complete departure from nearest vertical Scrollable viewport.
- [ ] Sustained 60 FPS benchmark not measured.
