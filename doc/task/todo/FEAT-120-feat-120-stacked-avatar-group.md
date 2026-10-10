---
id: FEAT-120
title: StackedAvatarGroup — Cụm avatar bạn bè/clan xếp chồng chéo kèm số dư +N
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Trong game casual có yếu tố mạng xã hội (bạn bè đang online, thành viên bang hội, người cùng chơi ván đấu), hiển thị cụm avatar xếp chồng là tiêu chuẩn ngành.

## Đề xuất phạm vi
Widget StackedAvatarGroup nhận danh sách avatar URL/Widget, hiển thị tối đa N avatar xếp đè lên nhau với viền trắng bo tròn và badge tròn số lượng dư (ví dụ: +5) ở cuối.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra cắt danh sách hiển thị đúng maxAvatars và tính toán đúng số dư còn lại.
- [ ] **Widget test**: Truyền 6 avatar với max=3, kiểm tra 3 avatar đầu hiển thị đè nhau và ô thứ 4 hiển thị '+3'.
- [ ] **Integration test**: Hiển thị cụm avatar bạn bè trên thanh leaderboard trong app trên thiết bị thật.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Layout Row xếp chồng bằng Positioned/negative margin đơn giản, zero overhead.
