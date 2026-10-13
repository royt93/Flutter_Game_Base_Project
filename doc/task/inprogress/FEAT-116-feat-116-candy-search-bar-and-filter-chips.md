---
id: FEAT-116
title: CandySearchBar & FilterChipRow — Thanh tìm kiếm kèm hàng tag lọc chip nảy
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Tìm kiếm vật phẩm trong kho đồ, lọc thẻ bài theo hệ/thuộc tính là tính năng phổ biến trong app/game casual có nhiều nội dung.

## Đề xuất phạm vi
Thanh tìm kiếm CandySearchBar có nút xoá nhanh (clear), kết hợp FilterChipRow cuộn ngang với các chip nảy đàn hồi khi được chọn.

## Kiểm thử
- [x] **Unit/widget test**: Debounced latest search text/clear, callback and immutable selected-filter set; duplicate filter IDs/invalid debounce.
- [x] **Showcase test**: Search/clear then toggle chip; caller-controlled status updates.
- [x] **Physical-device smoke**: Pixel 7 Pro (replacing disconnected SM-S928B per user direction); typed/cleared search, selected filter chip and closed keyboard successfully. No simulator used.
- [x] **Host validation**: root 2963/example 246 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] 300ms debounce; chip row uses RepaintBoundary; Reduced Motion disables bounce duration.
- [ ] 60 FPS benchmark not measured.
