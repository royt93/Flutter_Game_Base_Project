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

## Kiểm thử
- [x] **Unit test**: Preset mapping, injected AudioManager + platform-haptic initiation order, muted SFX, haptics disabled, missing services, and invalid path.
- [x] **Widget test**: All six showcase buttons trigger without framework errors.
- [x] **TECNO E2E smoke**: Six preset taps on TECNO KJ7 pass. E2E build disables AudioManager, so this run validates taps/haptics only.
- [x] **TECNO profile invocation smoke**: Audio-enabled profile build tapped all six presets using `assets/audio/demo_sfx.mp3`; app remained foreground with no framework/plugin error. Perceptual sound/haptic timing was not instrumentally verified and still needs human listening confirmation.

## Hiệu năng & resource
- [x] Starts existing pooled AudioManager playback and one existing preference-aware haptic; no new per-call preset/list object.
- [ ] Sustained FPS/GC benchmark not measured.
