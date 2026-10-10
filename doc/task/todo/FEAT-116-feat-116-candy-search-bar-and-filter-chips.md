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

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra gõ text tìm kiếm bắn sự kiện onChanged sau debounce; chọn chip cập nhật danh sách active filters.
- [ ] **Widget test**: Gõ từ khoá vào search bar, bấm nút clear kiểm tra ô tìm kiếm trống; tap chip lọc kiểm tra trạng thái đổi sang selected.
- [ ] **Integration test**: Thử tìm kiếm và lọc danh mục vật phẩm trên thiết bị thật, bàn phím mở/đóng không lỗi layout.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Debounce tìm kiếm 300ms tránh spam lọc, RepaintBoundary cho hàng chip.
