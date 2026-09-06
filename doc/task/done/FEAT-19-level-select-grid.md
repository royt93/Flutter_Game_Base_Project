---
id: FEAT-19
title: LevelNodeButton / LevelSelectGrid — widget world-map/level-select
type: feature
priority: P1
effort: M
source: user pick (đã chốt trong phiên chọn widget mới)
---

## Vì sao cần
Màn hình chọn level (world map/level grid) là màn hình chuẩn của mọi casual
game nhưng kit hiện không có widget nào cho pattern này — gap lớn nhất trong
nhóm widget theo audit.

## Đề xuất phạm vi
- `LevelNodeButton`: nút tròn 1 level, nhận `state` (`locked`/`unlocked`/`completed`),
  `starsEarned` (0-3, dùng lại `StarRating` đã có làm badge mini), số thứ tự
  level. Trạng thái `locked` disable tap + hiển thị icon khoá.
- `LevelSelectGrid`: bố cục N `LevelNodeButton` (dùng `GridView`/custom layout
  dạng đường zigzag tuỳ chọn), không tự quản lý state tiến trình (nhận
  `List<LevelState>` từ ngoài vào — widget thuần hiển thị, giữ đúng triết lý
  "generic, game-agnostic" của các widget `common/` khác).

## Yêu cầu test
- **Unit test**: logic thuần quyết định hiển thị icon/màu theo `state` (nếu tách được thành hàm/enum riêng).
- **Widget test**: dựng `LevelNodeButton` cho cả 3 state, assert đúng icon/khoá/tap có hoạt động hay bị chặn đúng theo state; dựng `LevelSelectGrid` với danh sách hỗn hợp state, assert số node render đúng.
- **Integration test**: `example/integration_test/` — dựng 1 màn hình demo `LevelSelectGrid` thật, tap vào 1 node `unlocked`, verify callback được gọi trên thiết bị/emulator thật.

## Demo
Thêm section "Level Select" trong `WidgetShowcaseScreen`, dữ liệu mẫu 8-10 level với đủ 3 trạng thái.

## Acceptance criteria
- [ ] `locked` node không thể tap (test xác nhận callback không được gọi).
- [ ] Đủ 3 loại test + demo trong showcase.
