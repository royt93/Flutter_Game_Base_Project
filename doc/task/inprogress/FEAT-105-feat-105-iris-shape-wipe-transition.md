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

## Yêu cầu kiểm thử
- [x] **Unit test**: Tính bán kính đến góc xa nhất cho tâm giữa màn hình và góc màn hình; shape path rỗng ở 0 và phủ viewport ở 1.
- [x] **Widget test**: Iris cover/reveal khóa rồi mở pointer; Star Reduced Motion snaps; cancel cân bằng clip/pointer.
- [x] **Showcase test**: Chọn Iris/Star/Diamond cập nhật shape.
- [x] **TECNO integration smoke**: Chọn Iris trong showcase, chạy scene transition và xác nhận `Scene #2`/phase idle trên TECNO KJ7.

## Hiệu năng & Animation
- [x] CustomClipper tái sử dụng path per frame progression, clips only during transition; controller dispose.
- [ ] 60 FPS benchmark: chưa đo riêng frame-time cho từng wipe shape.
