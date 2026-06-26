---
id: w22-1-game-feel-juice
title: Game Feel / Juice — trail gem rơi + visual gem hiếm + tinh chỉnh
wave: 22
phase: 1
status: todo
owner: claude
---

# Phase 1 — Game Feel / Juice

## ⚠️ Phần lớn ĐÃ CÓ — đây là *augment*, không xây mới

| Juice | Trạng thái | File:line |
|---|---|---|
| Screen shake (trauma-based, tự decay) | ✅ có | `lib/game/neon_jewel_game.dart:500` (`_trauma`), `:583` (apply), `:2707` (`_shake`) |
| Slow-motion wombo (combo≥6, 0.32×, 0.45s) | ✅ có | `:511` (`_timeScale`), `:515` (`_triggerSlowmo`), `:527` (`super.update(dt*_timeScale)`), `:2734` |
| Combo text ("WOMBO COMBO x6!") | ✅ có | `:2715` (`_spawnComboText`), `effects.dart:827` (`ComboTextComponent`) |
| Particle burst khi clear (9/18 hạt, BlendMode.plus) | ✅ có | `:2359` (`_spawnBurst`), cap `_burstCap` `:1656` |
| Shockwave + Flash | ✅ có | `effects.dart:782` (`ShockwaveComponent`), `:186` (`FlashOverlay`) |
| Audio pentatonic theo combo + arpeggio wombo | ✅ có | `core/audio_manager.dart:105` (`noteIndexFor`), `:119` (`playMelodic`) |
| Gem glow/pulse (sin-wave) | ✅ có | `gem_component.dart:61` (`render`), `:22` (`_pulse`) |
| **Trail khi gem RƠI** | ❌ thiếu | gem chỉ animate position, không emit particle |
| **Visual gem hiếm (lucky)** | ⚠️ chỉ flag | `gem_component.dart:26` (`isLucky`) — chưa có pulse/trail riêng |

## Mục tiêu Wave 22 (3 việc thêm)

### 1.1 Trail khi gem rơi (settle)
- Khi gem di chuyển nhanh lúc settle (vận tốc > ngưỡng), emit **particle trail mờ** (vài hạt
  fade nhanh) tại vị trí cũ → cảm giác "rơi có đuôi".
- Thêm trong `GemComponent` (hoặc layer particle): trong `update`/move-tween, nếu `dy` lớn →
  spawn `Particle` ngắn (lifespan ~0.15s, alpha thấp, BlendMode.plus, màu = màu gem).
- ⚠️ Perf: cap số trail/frame (giống `_burstCap` `:1656`); chỉ trail gem rơi xa (≥2 ô).

### 1.2 Visual gem hiếm (lucky gem)
- Gem `isLucky` (`gem_component.dart:26`): thêm **pulse scale mạnh hơn + glow màu cầu vồng**
  + (tuỳ chọn) star sparkle nhỏ quanh gem → người chơi NHẬN RA gem thưởng.
- Render trong `GemComponent.render` (`:61`): nếu `isLucky` → glowScale ×1.4, pulse nhanh ×1.5,
  thêm 3-4 chấm sparkle xoay (tái dùng pattern `_MapPainter` blur+halo).

### 1.3 Tinh chỉnh thang cường độ theo cascade depth
- Hiện wombo = combo≥6 (`:2716`), haptic medium = combo≥4 (`:2736`). Thêm **bậc trung gian**:
  - combo 3 → shake nhẹ (`_shake(4)`) + flash mờ
  - combo 4-5 → shake vừa + combo text màu nóng
  - combo ≥6 → wombo (đã có: slow-mo + shake mạnh + arpeggio)
- Mục tiêu: leo thang mượt, không nhảy thẳng "im lặng → bùng nổ".

## Accessibility (bắt buộc)
- Thêm cờ Settings `juiceReduced` (StorageKeys mới): bật → tắt slow-mo + giảm shake 50% +
  tắt trail. Đọc cờ trong `neon_jewel_game.dart` trước khi `_triggerSlowmo`/`_shake`/trail.
- Lý do: tránh motion sickness; nhiều store yêu cầu tuỳ chọn giảm chuyển động.

## Thứ tự triển khai
1. Cờ `juiceReduced` (storage + Settings toggle + đọc trong game).
2. 1.3 tinh chỉnh thang (rẻ nhất, chỉ điều chỉnh số + thêm nhánh combo 3-5).
3. 1.1 trail gem rơi (particle, cap perf).
4. 1.2 visual gem hiếm.
5. Test + analyze 0 + chạy thật trên device (quan sát 60fps, không giật khi cascade dài).

## Acceptance criteria
- [ ] Combo 3/4-5/≥6 có cường độ tăng dần rõ rệt (không nhảy bậc).
- [ ] Gem rơi xa có trail mờ; **không tụt FPS** khi cascade dài (cap particle hoạt động).
- [ ] Gem hiếm nhìn là biết ngay (pulse + glow cầu vồng khác hẳn gem thường).
- [ ] `juiceReduced=true` → tắt slow-mo, shake giảm, trail tắt; gameplay vẫn chơi được.
- [ ] Không đụng logic match/score; side-mode vẫn đúng.
- [ ] `flutter analyze` 0 issue; test logic (nếu tách được hàm thuần cho thang cường độ).

## Lưu ý
- Phần lớn hạ tầng có sẵn → effort thực tế nhỏ (S–TB), giá trị "wow" cao.
- Particle perf là rủi ro chính → luôn cap + test cascade dài trên máy thật.
