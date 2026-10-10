---
id: ENH-98
title: Continuous / Responsive CurrencyCounter — lăn số mượt mà khi nhận chuỗi thưởng liên tiếp
type: enhancement
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
CurrencyCounter hiện dùng TweenAnimationBuilder tĩnh 500ms; khi nhận chuỗi thưởng dồn dập (nhiều quest, combo), số bị giật khựng hoặc reset điểm bắt đầu.

## Đề xuất phạm vi
Nâng cấp CurrencyCounter hỗ trợ AnimationController chủ động, giữ vận tốc lăn số khi giá trị đích tăng liên tục, hỗ trợ tap để hoàn tất tức thì (skip to end).

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [x] **Unit test**: Kiểm tra tính toán giá trị nội suy khi đích thay đổi giữa chừng; tính năng skipToEnd đặt giá trị ngay lập tức.
- [x] **Widget test**: Bơm giá trị mới liên tiếp trong khi đang animate, kiểm tra số hiển thị tăng liên tục không bị giật lùi về 0.
- [x] **Integration test**: Nhận chuỗi thưởng 5 lần liên tiếp trên màn hình Shop/Reward, số tiền nhảy trơn tru trên thiết bị thật.

## Yêu cầu hiệu năng & Animation
- [x] **60 FPS & Resource cleanup**: Ticker dọn sạch khi unmount, không setState khi giá trị hiển thị không đổi chữ số.
