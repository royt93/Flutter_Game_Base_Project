---
id: w21-4-rhythm-upgrade
title: Rhythm Mode — BPM dynamic + judgment animation
wave: 21
phase: 4
status: done
owner: claude
---

# Phase 4 — Rhythm Mode Upgrade

## Vấn đề hiện tại

Rhythm hiện tại (Wave 8.2): BPM cố định 100, judgment window ±0.14s cố định, groove bar 8 nấc,
text "ĐÚNG/LỆCH NHỊP" xuất hiện nhưng không ấn tượng. Thiếu cảm giác leo thang độ khó.

## Thiết kế mới

### BPM Dynamic (tăng dần theo groove)

Groove level → BPM:
- Groove 0-2: BPM 80 (slow, easy to hit)
- Groove 3-5: BPM 100 (current baseline)
- Groove 6-7: BPM 120 (fast, requires focus)
- Groove 8 (max): BPM 140 + judgment window thu hẹp → ±0.10s

`RhythmClock` đã tách biệt (pure Dart) — chỉ cần expose `currentBpm` getter, cập nhật trong
`tickRhythm` theo `groove.value`.

### Judgment Animation (visual feedback)

Thay text thuần bằng animated badge bay lên:
- **PERFECT** (±0.05s) → vàng + particle burst nhỏ, scale 1.3×→1.0
- **GOOD** (±0.10s) → xanh lam
- **LATE/EARLY** (±0.14s) → cam
- **MISS** (>0.14s) → đỏ + groove reset

Animation: `AnimatedOpacity` + `AnimatedSlide` lên rồi fade (0.6s). Tái dùng pattern
`ComboText` đã có trong `GameScreen`.

### Beat Indicator đẹp hơn

Chấm nhịp hiện tại → thay bằng 4 dot nhịp đập (hình trái tim hoặc bar equalizer neon):
- Dot sáng lên đúng beat → người chơi dễ canh hơn.
- Màu dot thay đổi theo BPM (xanh → vàng → đỏ).

## Triển khai

- `rhythm_clock.dart`: thêm `currentBpm(int groove)` pure function.
- `game_controller_modes.dart` `tickRhythm()`: update `rhythmClock.bpm = currentBpm(groove.value)`.
- `game_controller_modes.dart` `judgeRhythmBeat()`: return `JudgeResult` enum thay vì bool.
- `GameScreen`: `_JudgmentBadge` widget (fly-up animation); nhận `JudgeResult` qua Rx.
- HUD rhythm: thay dot đơn bằng `RhythmBeatIndicator` (4 dot, pulse animation).

## Test
- `currentBpm` trả đúng theo groove level (unit test, pure).
- `judgeRhythmBeat` phân loại đúng PERFECT/GOOD/LATE/MISS.
- Widget test: `RhythmBeatIndicator` mount OK.
- Regression: 611 test pass.

## Lưu ý
- `RhythmClock` không dùng `DateTime.now` (đã đúng) — giữ nguyên invariant này.
- BPM thay đổi chỉ ảnh hưởng beat interval, KHÔNG ảnh hưởng `dt` engine.
- Liên quan: [[side-mode-isolation]], `rhythm_clock.dart`.
