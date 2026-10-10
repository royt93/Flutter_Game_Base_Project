---
id: FEAT-112
title: ScratchCard — Thẻ cào may mắn tương tác ngón tay lộ phần thưởng
type: feature
priority: P1
effort: L
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Minigame thẻ cào cực kỳ hấp dẫn cho các sự kiện may mắn, người chơi dùng ngón tay cào lớp nhũ để dần lộ ra giải thưởng bên dưới.

## Đề xuất phạm vi
Widget ScratchCard nhận background widget (quà) và cover widget (lớp nhũ bạc/vàng), cho phép cào bằng cử chỉ ngón tay, tính toán % đã cào và tự động mở toang khi đạt >60%.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán diện tích cào được và trigger callback onRevealed khi vượt ngưỡng 60%.
- [ ] **Widget test**: Mô phỏng gesture drag qua lại trên mặt thẻ, kiểm tra lớp phủ bị xoá mờ và callback onThresholdReached được gọi.
- [ ] **Integration test**: Dùng ngón tay cào thẻ cào trên màn hình cảm ứng TECNO, kiểm tra đường cào mượt không bị đứt nét.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Vẽ vết cào lên bitmap nháp bằng Canvas BlendMode.clear, tối ưu redraw chỉ trong bounding box nét cào.
