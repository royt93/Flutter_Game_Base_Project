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

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra trạng thái isExpanded, toggle mở/đóng và callback onExpansionChanged.
- [ ] **Widget test**: Tap header, kiểm tra content mở ra mượt mà và icon chevron xoay góc tương ứng.
- [ ] **Integration test**: Mở 3 mục accordion liên tiếp trong màn hình trợ giúp trên thiết bị thật, kiểm tra không bị giật cuộn trang.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Chỉ build child content khi mở nếu cấu hình lazy, dọn controller khi unmount.
