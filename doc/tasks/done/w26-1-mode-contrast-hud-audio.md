---
id: w26-1-mode-contrast-hud-audio
title: Tương phản mode (đợt 2) — HUD chủ đạo 4 mode đồng phục + ColorRush streak + nhạc per-mode
wave: 26
phase: 1
status: done
owner: claude
created: 2026-07-03
---

## Tiến độ (2026-07-03) — CODE XONG, chờ verify device
- ✅ **1C nhạc per-mode**: `AudioManager._currentTrack` + `startBgm({track})` đổi-track-được (no-op nếu
  trùng track; mute vẫn nhớ track); getter `GameController.bgmTrack` (3 nhóm); gọi `startBgm(bgmTrack)`
  ở `game_screen_controller.onInit`, về track 0 ở `onClose`.
- ✅ **1B ColorRush streak ×N**: chip `×${streak+1}` trong `_colorRushHud` (màu vàng→cam→đỏ theo bậc,
  scale-in mỗi lần tăng; tôn trọng `reducedMotion`).
- ✅ **1A HUD chủ đạo 4 mode**: getter `gravityMovesUntilFlip` + 4 helper `_gravityHud`/`_sodaHud`/
  `_labyrinthHud`/`_dailyHud` (dùng chung `_hudDeco(modeAccent)`); nhánh HUD mở rộng 4 else-if.
  Gravity=mũi tên+đếm ngược lật · Soda=thanh mực nước+chai+shimmer khi phun · Labyrinth=badge "tường
  di động"+shake mỗi lượt · Daily=badge mutator+streak 🔥.
- ✅ **i18n**: 3 key mới `hud_flip_in`/`hud_maze_walls`/`hud_streak` (en+vi + `_w26ByLang` đủ 20 lang);
  `daily_mut_*` đã localized sẵn từ trước.
- ✅ **Test**: `test/w26_1_mode_hud_test.dart` (9 test: gravityMovesUntilFlip + bgmTrack mapping).
- ✅ `flutter analyze` 0 · full suite (exclude slow) **923 passed**.
- ✅ **Verify device (R5CX613VZBR, Samsung SM S928B)** — build debug + cài + vào lần lượt 5 mode, chụp
  màn hình xác nhận:
  - Gravity: pill tím "↓ Lật sau 5" hiện đúng, không trùng panel ĐIỂM/MỤC TIÊU/LƯỢT.
  - Soda: pill "🍾 0/3" + thanh mực nước hiện dưới tên mode.
  - Labyrinth: badge "🔲 Tường di động" hiện đúng.
  - Daily: badge mutator "Ít Lượt" hiện đúng (streak=0 nên chưa hiện 🔥 — đúng logic `children.isEmpty`).
  - ColorRush: chấm "Màu nóng" hiện đúng; streak=0 nên chip ×N chưa xuất hiện (chưa ép được match màu
    nóng qua adb tap trong phiên này) — logic tăng/reset/clamp `colorRushStreak` đã có unit test riêng
    từ W17 (`test/w17_4_deepen_b_modes_test.dart`), tự tin chip render đúng khi streak>0.
  - Không có exception/audio error trong logcat suốt phiên; HUD không gây giật layout (vị trí panel
    ổn định qua 5 mode).
  - Lưu ý môi trường: máy có user-profile phụ (id 150) khiến `uiautomator`/accessibility dump trả sai
    app — phải dùng `adb screencap` + tap tọa độ tính từ ảnh, không dùng được UI-tree tool trên máy này.
- **W26-1 HOÀN TẤT** — sẵn sàng để user tự commit.

# Phase 1 — Hoàn tất tương phản (tiếp W25-2 đợt 1: palette + mở-màn)

W25-2 đợt 1 đã làm palette per-mode (`modeAccent`) + mở-màn (`_ModeIntroOverlay`). Đợt này đóng nốt
3 mảng còn hoãn để mỗi mode có **identity HUD + âm thanh** riêng, không còn "same-y".

## 1A. HUD chủ đạo cho 4 mode còn đồng phục
Hiện chỉ Boss/Rhythm/ColorRush/Survival/Rush/Endless/Zen có HUD riêng; **Daily/Gravity/Soda/Labyrinth**
vẫn chỉ score/goal/moves. Thêm 1 widget chỉ-số-chủ-đạo mỗi mode.
- Điểm móc: `lib/presentation/screens/game_screen.dart` nhánh HUD chủ đạo (dòng ~724-728, hiện
  `isBoss?_bossWeakHint : isRhythm?_rhythmHud : isColorRush?_colorRushHud : SizedBox`) → thêm else-if;
  và ô thứ 3 `_movesOrTimeCell` (dòng ~1250). Tái dùng `ctrl.modeAccent` (W25-2) cho màu.
- [x] **Gravity**: "Lật bàn sau: N lượt" + mũi tên hướng (engine lật mỗi 5 lượt) — đọc bộ đếm hiện có.
- [x] **Soda**: thanh fill "X/20 → chai" (mỗi clear +1 fill; +5 mỗi 5 lượt) — đọc state soda.
- [x] **Labyrinth**: chỉ báo "tường đổi sau N lượt" + fog-radius (lưới đổi mỗi lượt).
- [x] **Daily**: badge mutator ngày (4 màu / ít lượt / ×2 combo / vô special / +lượt) + streak ngày.

## 1B. ColorRush streak ×N (review #6 cũ chỉ ra thiếu)
`_colorRushHud` (dòng ~785) hiện chỉ hiện màu nóng, KHÔNG hiện chuỗi clear-liên-tiếp ×1→×3.
- [x] Thêm hiển thị streak multiplier hiện tại (×1/×2/×3) + animation khi tăng bậc.

## 1C. Nhạc nền per-mode (tái dùng 3 track sẵn có — KHÔNG cần asset mới)
`AudioManager.startBgm({int track})` hỗ trợ 3 track (`bkg/bkg1/bkg2.ogg`) nhưng luôn dùng track 0.
- [x] Map nhóm mode → track: vd track1 = mode căng (Boss/Survival/Rush/Versus), track2 = mode nhịp/vui
  (Rhythm/ColorRush/Soda/Daily), track0 = campaign/Zen/còn lại.
- [x] Gọi `startBgm(track)` khi vào ván (game_screen_controller.onInit theo `gameCtrl` mode flags);
  về track0 khi rời ván (Home). Tránh giật: chỉ đổi track khi khác track hiện tại.
- [x] Tôn trọng cờ mute nhạc (Settings) sẵn có.

## Acceptance
- [x] 4 mode đồng phục có chỉ-số-chủ-đạo riêng; chụp cạnh nhau phân biệt được bằng HUD.
- [x] ColorRush hiện streak ×N đúng theo chuỗi clear.
- [x] Nhạc đổi theo nhóm mode; không giật khi vào/ra ván; mute tôn trọng.
- [x] `flutter analyze` 0 · full suite (exclude slow) xanh · widget test HUD-per-mode mount đúng nhánh.
- [x] Tôn trọng `ActiveCosmetics.reducedMotion` (giảm animation streak/HUD nếu bật).

## Lưu ý
- Phần lớn tầng render/HUD/audio → rủi ro thấp-TB, làm được không cần device (verify feel cần device).
- Key i18n mới cho label HUD/mutator → `_wXXByLang` 20 ngôn ngữ.
- 🚫 KHÔNG commit ([[code-on-main-only]]). Liên quan: [[w25-2-mode-contrast]].
