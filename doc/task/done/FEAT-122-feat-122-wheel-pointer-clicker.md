---
id: FEAT-122
title: WheelPointerClicker — Kim chỉ vòng quay nảy rung vật lý theo từng nan quạt
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
WheelSpinner hiện tại có kim chỉ đứng yên khi vòng quay quay. Vòng quay chuyên nghiệp luôn có chiếc kim nảy lắc (tick bounce) theo từng nan quạt đi qua kèm âm thanh cạch cạch.

## Đề xuất phạm vi
Mở rộng WheelSpinner thêm widget con WheelPointerClicker tự động tính toán góc tiếp xúc của các nan quạt, xoay góc kim nảy nhẹ mỗi khi nan quạt đi qua và phát haptic/sfx tick.

## Kiểm thử
- [x] **Unit test**: Segment-boundary crossings in both directions, exact-boundary behavior, zero motion, pointer kick direction/decay/clamp.
- [x] **Widget test**: Pointer angle oscillates during spin; `onTick` fires for crossed slices; landing callback/result stays correct; Reduced Motion produces no tick/bounce.
- [x] **Showcase test**: Wheel ticks increment during spin and landed toast remains intact.
- [x] **Physical integration**: TECNO KJ7 (115333744A005844) pointer bounced during spin, ticks emitted, wheel landed on requested segment. No simulator.
- [x] **Host validation**: root 2989/example 250 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Pointer deflection derives directly from WheelSpinner's rotation frames; no separate timer/controller.
- [ ] Sustained 60 FPS benchmark not measured.
