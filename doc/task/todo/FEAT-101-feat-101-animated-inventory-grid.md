---
id: FEAT-101
title: AnimatedInventoryGrid — hiệu ứng hoán đổi vị trí và pop-in item mềm mại
type: feature
priority: P1
effort: L
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
InventoryGrid hiện tại nhảy vị trí tức thì khi kéo thả hoặc nhặt đồ, thiếu cảm giác mềm mại cao cấp chuẩn game casual.

## Đề xuất phạm vi
Thêm hiệu ứng hoạt họa chuyển vị trí (layout translation) khi sắp xếp ô đồ và pop-in scale (0.8 -> 1.0) khi ô mới được lấp đầy, tích hợp mượt với InventoryService.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán toạ độ dịch chuyển giữa 2 chỉ số slot cũ và mới trong grid.
- [ ] **Widget test**: Thao tác reorder ô đồ, kiểm tra AnimatedPositioned/SlideTransition chạy mượt và cập nhật đúng snapshot dữ liệu.
- [ ] **Integration test**: Kéo thả sắp xếp balo 20 ô trên thiết bị thật, kiểm tra không bị lệch hitbox hay giật hình.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Giới hạn render trong khung nhìn, chỉ animate các ô có toạ độ thực sự thay đổi.
