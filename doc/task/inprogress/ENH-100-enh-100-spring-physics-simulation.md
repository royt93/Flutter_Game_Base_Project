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
Cung cấp SpringScaleTransition và SpringSimulationController với preset bouncy/gentle/snappy. PressableScale dùng spring cho press/release; RewardPopup dùng spring cho entrance. CommonButton kế thừa hành vi qua PressableScale.

## Kiểm thử
- [x] **Unit test**: SpringSimulation hội tụ về 1.0 và vận tốc giảm dưới ngưỡng; preset `bouncy/gentle/snappy` có cấu hình phân biệt.
- [x] **Unit test**: SpringSimulation hội tụ về 1.0 và vận tốc giảm dưới ngưỡng; preset `bouncy/gentle/snappy` có cấu hình phân biệt.
- [x] **Widget test**: Press, release, cancel, quick re-tap/interrupt, bouncy overshoot, settle exact rest, Reduced Motion bật giữa gesture, disabled state, focus/keyboard unchanged.
- [x] **Widget test popup**: RewardPopup spring settles, Reduced Motion snap, unmount mid-animation disposes safely.
- [x] **TECNO integration smoke**: `PressableScale` `Primary` nhận tap; RewardPopup spring controller reaches rest on TECNO KJ7.
- [x] **Host validation**: root 2902 tests, example 232 tests; analyzers and quality gates pass.

## Hiệu năng & lifecycle
- [x] Simulation ends at spring tolerance and controller snaps to exact target; all controllers disposed on unmount.
- [ ] 60 FPS benchmark: chưa có workload/frame-time baseline riêng cho ENH-100; không tuyên bố sustained 60 FPS.
