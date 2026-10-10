---
id: FEAT-103
title: CardFlip 3D & Gleam Sweep — Lật thẻ bài 3D phối cảnh kèm vệt sáng quét kim loại
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Gacha, bốc thẻ bài may mắn, mở thưởng đặc biệt luôn cần hiệu ứng lật thẻ 3D hồi hộp kèm tia quét sáng lấp lánh khi lộ thẻ hiếm.

## Đề xuất phạm vi
Widget CardFlip3D nhận front/back widget, góc quay Y với Transform Matrix4 perspective, và hiệu ứng GleamSweep (vệt sáng chạy chéo qua thẻ sau khi lật).

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán ma trận xoay góc 0..pi, trạng thái hiển thị mặt trước/sau tại mốc pi/2.
- [ ] **Widget test**: Tap để lật thẻ, kiểm tra mặt trước ẩn đi và mặt sau hiện lên ở nửa sau của animation, tia sáng quét đúng chu kỳ.
- [ ] **Integration test**: Lật liên tiếp 3 thẻ bài gacha trên thiết bị thật, đo hiệu năng dựng hình 3D mượt mà.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Sử dụng RepaintBoundary cho từng mặt thẻ, ngắt tia quét sáng khi reducedMotion bật.
