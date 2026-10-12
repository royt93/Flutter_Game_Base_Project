---
id: FEAT-115
title: StaggeredAnimatedGrid — Lưới card danh mục/shop hiệu ứng gợn sóng cascade
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Khi mở màn hình Shop, chọn nhân vật, danh mục vật phẩm, hiển thị lưới tĩnh rất khô cứng; hiệu ứng xuất hiện gợn sóng tuần tự tạo cảm giác cao cấp.

## Đề xuất phạm vi
Widget StaggeredAnimatedGrid tự động tính toán delay từng ô theo hàng/cột (offset theo ma trận i, j), làm các thẻ bài trượt nảy vào vị trí với độ trễ 40ms.

## Kiểm thử
- [x] Unit test: row/column delay and invalid configuration.
- [x] Widget test: six-cell cascade order/timing, last-cell tap, Reduced Motion bypass; offscreen disposal cancels delay.
- [x] S24 Ultra smoke (SM-S928B): opened Showcase, scrolled to staggered tiles, tapped last tile successfully; no simulator.
- [ ] Dispose/cancel offscreen delay test pending.

## Hiệu năng & Animation
- [x] Lazy GridView; each visible item owns/cancels one entrance timer/controller; Reduced Motion bypasses wrappers.
- [ ] Sustained 60 FPS benchmark not measured.
- [x] Root 2960/example 245 suites and full quality gates pass.
