---
id: FEAT-105
title: Iris / Shape Wipe Transition — Chuyển cảnh vòng tròn & ngôi sao co giãn
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Chuyển cảnh đen mờ (fade) quá đơn điệu cho casual game. Kiểu mở/đóng hình tròn (Iris wipe) từ vị trí tâm chơi mang lại phong cách vui nhộn kinh điển.

## Đề xuất phạm vi
Mở rộng SceneTransitionOverlay với kiểu wipe: Iris (tròn), Star (ngôi sao), Diamond (hình thoi) co giãn từ tâm toạ độ chỉ định, che kín hoặc mở toang màn hình.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán bán kính che phủ toàn màn hình dựa trên kích thước màn hình và tâm điểm wipe.
- [ ] **Widget test**: Kích hoạt Iris transition, kiểm tra CustomPainter clip path mở rộng từ r=0 đến r_max và mở khoá chạm màn hình khi hoàn tất.
- [ ] **Integration test**: Chuyển từ GameDemo sang LevelSelectGrid bằng Iris transition trên thiết bị thật.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tối ưu đường vẽ Path, không tạo Path mới nếu bán kính không đổi.
