---
id: FEAT-104
title: JankDetector & Live Frame Graph cho Debug QA Overlay
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Partner yêu cầu kiểm soát hiệu năng gắt gao; dev cần nhìn thấy biểu đồ frame time thực tế ngay trên màn hình game để bắt kịp thời điểm bị drop frame.

## Đề xuất phạm vi
Widget LiveFrameGraph hiển thị thanh biểu đồ 60/120 FPS gần nhất, phân loại frame xanh/vàng/đỏ (dưới 16.6ms / trễ >33ms) tích hợp tab mới trong DebugQaOverlay.

## Kiểm thử
- [x] **Unit test**: FrameTiming classification normal/slow/jank and bounded 100-sample buffer.
- [x] **Widget test**: injected FrameTiming samples update graph columns, FPS/jank summary and stop after unmount.
- [x] **Integration test**: TECNO KJ7 (115333744A005844) opened Debug QA → Frames, exercised Showcase scrolling; LiveFrameGraph received real FrameTiming samples and reported non-zero FPS/jank summary. No simulator.
- [x] **Host validation**: root/example suites, analyzers and quality gates passed in prior full validations of the current implementation.

## Hiệu năng & Resource cleanup
- [x] Debug/profile-only panel; graph subscribes only while Frames tab is mounted, throttles redraws to 100 ms, and cancels timer/subscription or scheduler callback on dispose.
- [x] Rolling sample capacity defaults to 100.
- [ ] Sustained 60 FPS benchmark not measured.
