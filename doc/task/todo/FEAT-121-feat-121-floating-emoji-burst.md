---
id: FEAT-121
title: FloatingEmojiBurst — Emoji tương tác thả tim/cười bay lượn từ góc màn hình
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Người chơi rất thích thả tim, thả biểu cảm vỗ tay/cười vui khi bạn bè ghi điểm hoặc trong phòng chơi chung (tương tự Monopoly Go / TikTok live).

## Đề xuất phạm vi
Widget FloatingEmojiBurst nhận trigger emoji (tim, cười, vỗ tay...), sinh ra các biểu tượng bay bổng zíc zắc từ góc màn hình lên trên rồi mờ dần biến mất.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán toạ độ bay zíc zắc ngẫu nhiên bằng sin wave và độ mờ opacity giảm dần về 0.
- [ ] **Widget test**: Kích hoạt thả tim 5 lần, kiểm tra 5 emoji bay lên màn hình và tự dọn dẹp khi bay hết chiều cao.
- [ ] **Integration test**: Thả tim liên tục trong phòng chơi trên TECNO, hiệu ứng bay bổng mượt mà.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Giới hạn tối đa 20 emoji đồng thời, tự hủy timer khi emoji bay ra khỏi màn hình.
