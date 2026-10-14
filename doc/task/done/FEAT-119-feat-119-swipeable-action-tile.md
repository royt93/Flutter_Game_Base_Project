---
id: FEAT-119
title: SwipeableActionTile — Thẻ danh sách vuốt lộ nút xoá/nhận quà kèm haptic
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Hòm thư nhận quà, danh sách thông báo, danh sách quest thường cần thao tác vuốt ngang để thực hiện nhanh hành động (Xoá, Nhận quà, Đánh dấu đã đọc).

## Đề xuất phạm vi
Widget SwipeableActionTile bọc bất kỳ list item nào, hỗ trợ vuốt sang trái/phải để lộ các nút hành động nền, có độ đàn hồi lò xo (overscroll resistance) và rung haptic khi trượt qua ngưỡng.

## Kiểm thử
- [x] **Unit/widget tests**: thresholds/resistance, start/end actions, explicit action tap, close behavior, vertical scroll handoff, RTL and Reduced Motion.
- [x] **Showcase test**: swipe reveals Claim; status changes only after explicit action tap.
- [x] **Physical integration**: Samsung S24 Ultra (SM-S928B) swipe revealed Claim; separate tap invoked callback once and closed tile. No simulator.
- [x] **Host validation**: root 2973/example 248 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Horizontal GestureDetector lets vertical ListView drags win gesture arena; foreground uses Transform.translate; SpringSimulationController disposed on teardown.
- [ ] Sustained 60 FPS benchmark not measured.
