---
id: FEAT-117
title: CandySlider — Thanh trượt âm lượng/giá trị bo tròn với con trượt squash nảy
type: feature
priority: P0
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Trong Settings hiện dùng Slider mặc định của Flutter rất lạc lõng với theme kẹo neon. Cần thanh trượt candy dày dặn, con trượt viên kẹo co giãn khi kéo.

## Đề xuất phạm vi
Widget CandySlider có track bo tròn dày dặn, thumb viên kẹo nảy nhẹ (squash on drag), hiệu ứng phát sáng neon glow theo theme, hỗ trợ min/max/divisions.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [x] **Unit test**: Kiểm tra tính toán tỷ lệ % từ giá trị value/min/max và clamp đúng giới hạn.
- [x] **Widget test**: Kéo drag con trượt, kiểm tra thumb scale biến dạng nhẹ và callback onChanged phát ra giá trị tương ứng.
- [x] **Integration test**: Kéo thanh trượt chỉnh âm lượng trong Settings trên thiết bị thật TECNO, phản hồi trơn tru dưới ngón tay.

## Yêu cầu hiệu năng & Animation
- [x] **60 FPS & Resource cleanup**: Render track và thumb trên CustomPainter riêng biệt, không rebuild widget ngoài vùng slider.
