---
id: FEAT-108
title: GoldenShimmerText — Vệt sáng kim tuyến quét ngang chữ & điểm số lớn
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Điểm số jackpot, kỷ lục mới hoặc danh hiệu huyền thoại cần vệt sáng quét ngang ánh kim lấp lánh để tôn vinh thành tích.

## Đề xuất phạm vi
Widget GoldenShimmerText bọc StrokeText bằng ShaderMask gradient quét sáng tuyến tính từ trái qua phải theo chu kỳ định sẵn.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán offset gradient từ -1.0 đến 2.0 theo controller thời gian.
- [ ] **Widget test**: Kiểm tra ShaderMask hiển thị đúng màu kim loại vàng và tự dừng quét khi disableAnimations=true.
- [ ] **Integration test**: Hiện chữ 'JACKPOT 1,000,000' lấp lánh trên thiết bị thật trong màn hình ăn mừng.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Dùng LinearGradient shader nhẹ, tự pause khi widget không nằm trong khung nhìn.
