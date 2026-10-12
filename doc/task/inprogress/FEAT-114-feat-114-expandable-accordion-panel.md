---
id: FEAT-114
title: ExpandablePanel / AccordionTile — Thẻ nội dung gập/mở trơn tru
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Các app casual cần hiển thị FAQ, chi tiết trang bị, điều khoản, cài đặt mở rộng; cần thẻ accordion đóng mở mượt kèm mũi tên xoay.

## Đề xuất phạm vi
Widget ExpandablePanel nhận header, content, hỗ trợ tự mở rộng chiều cao bằng SizeTransition, icon mũi tên xoay 180° mượt mà, viền bo kẹo neon.

## Kiểm thử
- [x] Unit/widget: external expansion, toggle callback once, SizeTransition, lazy closed child, Reduced Motion, invalid duration.
- [x] Showcase: open 3 help topics sequentially.
- [x] Host validation: root 2954/example 244 suites; analyzers and quality gates pass.
- [x] S24 Ultra physical smoke (SM-S928B): opened three help topics sequentially; no simulator used.

## Hiệu năng & Animation
- [x] Lazy mode omits collapsed content until first open; controller disposes on unmount.
- [x] S24 Ultra (SM-S928B) profile with repeated three-topic open/close workload: LiveFrameGraph rolling 100-frame window showed 0 jank, all bars green, latest-frame estimate 259 FPS. Short sample only, not sustained 60 FPS proof.
