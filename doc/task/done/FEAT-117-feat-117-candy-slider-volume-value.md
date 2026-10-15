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
- [x] **Physical integration**: Settings BGM slider changed volume on Pixel 7 Pro (user-authorized device substitute); no simulator.
- [x] **Host validation**: root 2963/example 246 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] CandySlider uses native Flutter Slider rendering with a custom candy thumb and track theme; activation bounce uses native slider paint invalidation.
- [x] **Hiệu năng & resource**: Native slider paint invalidation, không rebuild widget ngoài vùng slider. Chưa đo sustained 60 FPS benchmark riêng (chấp nhận theo quy chuẩn, không tạo số liệu giả).
