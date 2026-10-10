---
id: ENH-100
title: SpringPhysics Simulation cho nút bấm và popup (vật lý lò xo thực)
type: enhancement
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Curve tĩnh dù có easeOutBack vẫn có cảm giác máy móc. Mô phỏng vật lý lò xo (SpringSimulation: mass, stiffness, damping) tạo cảm giác chạm nảy tự nhiên.

## Đề xuất phạm vi
Cung cấp SpringScaleTransition và SpringSimulationController hỗ trợ các preset: bouncy, gentle, snappy cho CommonButton, PressableScale và popup panels.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra phương trình SpringSimulation hội tụ về 1.0 và dừng animation khi vận tốc nhỏ hơn ngưỡng sai số.
- [ ] **Widget test**: Nhấn và thả nút bấm với SpringBounce, kiểm tra toạ độ nảy qua lại trước khi dừng hẳn ở scale 1.0.
- [ ] **Integration test**: Thử nghiệm cảm giác bấm trên màn hình cảm ứng TECNO, kiểm tra độ nhạy và không bị khựng.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tự động ngắt Ticker khi vật lý đạt trạng thái nghỉ (isDone), không chạy vô tận.
