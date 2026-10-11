---
id: FEAT-107
title: JuicyFeedback — Tự động đồng bộ Âm thanh + Rung theo preset cho Widget
type: feature
priority: P0
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Hiện tại dev phải tự gọi cả AudioManager và fireHaptic ở mọi nơi, dễ quên hoặc lệch nhịp. Cần 1 giải pháp 1 dòng lệnh tự đồng bộ âm thanh và cảm giác rung.

## Đề xuất phạm vi
Helper JuicyFeedback.trigger(JuicyPreset preset) với các preset: tap, pop, success, warning, chestOpen, coinTick. Tự kiểm tra AudioManager.muted và Haptics.enabled.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Preset mapping, đồng thời gọi SFX/haptic, mute và haptics-disabled gates, thiếu services safe no-op, invalid SFX path.
- [ ] **Widget test**: Tapping each JuicyFeedback showcase button invokes helper without exceptions.
- [ ] **TECNO integration smoke**: Tapping all presets on device validates gesture/haptic responsiveness. E2E build skips AudioManager initialization, so audio playback requires a separate profile/manual smoke with audio enabled.
- [ ] **Profile sound verification**: Use the example app's `assets/audio/demo_sfx.mp3` and confirm sound/haptic sync on TECNO with audio enabled.

## Hiệu năng & resource
- [ ] No sustained FPS/GC benchmark yet; helper starts one caller-owned SFX and one haptic operation, with no preset list/object allocation per trigger expected beyond normal Future/plugin work.
