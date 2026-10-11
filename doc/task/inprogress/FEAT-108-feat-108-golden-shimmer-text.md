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

## Yêu cầu kiểm thử
- [x] **Unit test**: Offset gradient đi từ -1.0 đến 2.0 và clamp ngoài khoảng.
- [x] **Widget test**: ShaderMask, StrokeText semantics, Reduced Motion static render, TickerMode pause/resume, duration validation.
- [x] **TECNO integration smoke**: Showcase Jackpot text mounts and animates without errors on TECNO KJ7.
- [x] **Host validation**: targeted tests and analyzers pass.

## Hiệu năng & Animation
- [x] LinearGradient + RepaintBoundary; ticker disposed on unmount and paused through inherited TickerMode/Reduced Motion.
- [ ] Automatic viewport visibility pausing is not implemented; lazy-list disposal/TickerMode are relied on. No dedicated 60 FPS benchmark yet.
