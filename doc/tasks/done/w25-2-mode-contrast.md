---
id: w25-2-mode-contrast
title: Tương phản cảm giác giữa các mode — chống "same-y"
wave: 25
phase: 2
status: done
owner: claude
created: 2026-07-02
---

> 🟢 **Đợt 1 (2026-07-02) — Palette + Mở-màn xong (code+test xanh):**
> - **A. Palette per-mode**: getter `GameController.modeAccent` (Boss=red · Rhythm=pink · Survival=cyan ·
>   Labyrinth=purple · ColorRush=orange · Soda=blue · Endless=magenta · Daily=lime · Puzzle=gold ·
>   Zen=teal · Gravity=indigo · Rush=red · Versus=yellow; campaign→accentForWorld). Dùng ở
>   `game_screen` (NeonBg accent) + aura shader (`neon_jewel_game.dart` `NeonGlowAura.color`).
> - **B. Mở-màn per-mode**: `GameScreenController.showModeIntro` + `modeIntroLabelKey` (getter
>   `GameController.modeIntroKey`, tái dùng title i18n sẵn — 0 key mới); overlay `_ModeIntroOverlay`
>   (StatefulWidget + AnimationController, `IgnorePointer` không chặn input, tự ẩn ~1.3s). Chỉ side-mode.
>   ⚠️ Dùng AnimationController (KHÔNG flutter_animate/Timer) để tránh rò pending-Timer trong widget test.
> - **Test** `test/w25_2_mode_contrast_test.dart` (modeAccent + modeIntroKey). `flutter analyze` 0 ·
>   full suite (exclude slow) **917 pass** (đã fix 15 smoke-test fail do pending Timer).
> - **Verify device (Samsung A11)**: Home/Boss render OK, không crash; Boss aura đáy ánh đỏ (palette có
>   tác dụng, khác cyan mặc định cũ). Mở-màn 1.3s không canh được screenshot qua adb (đã cover bằng test).
>   ⚠️ Popup "Google Play Protect / TestServices" khi verify là của HỆ THỐNG (adb test-services), KHÔNG
>   phải ad trong app — app vẫn không có ad SDK.
> 🔍 **Code-review W25 (2026-07-02, high) — 7 finding CONFIRMED đã sửa hết:**
> - #1 Meteor tạo match free: `_meteorSettleNoScore()` dọn match do refill KHÔNG ghi điểm (đòn boss
>   không tặng điểm/special/damage). #2 Meteor xoá special: `_pickMeteorCells` chỉ nhắm gem THƯỜNG
>   (bảo toàn rainbow/bomb/striped). #3 Endless mất accent rotation: khôi phục xoay theo `endlessStage`.
> - #4 Boss chẵn spike: `voidType` meteor về CHỈ phase 2 (bỏ meteor sớm phase 1). #5 Meteor nước cuối:
>   drop NGAY nếu `movesLeft<=0`. #6 3 dispatch trùng: gộp `modeAccent`+`modeIntroKey` về 1 `_modeSpec`
>   (Versus null-intro có chú thích). #7 comment stale flutter_animate→AnimationController.
> - Sau sửa: `flutter analyze` 0 · full suite **917 pass** · test w25 cập nhật theo profile voidType mới.
> - Verify device (A11) fix meteor: KHÔNG khả thi qua agent — meteor telegraph cần chơi match tay
>   (drag gem), máy A11 yếu + nhiều app test khác nhảy foreground (Sky Force) + ANR khi tap dồn lúc
>   load. App Neon Jewels chạy ổn (Home/Boss/HUD/palette OK); meteor để user tự cày. Hook debug đã GỠ,
>   rebuild bản sạch cài lại A11.
>
> **HOÃN Phase 2.2** (đã xong ở [[w26-1-mode-contrast-hud-audio]]): HUD riêng cho 4 mode đồng phục
> (Daily/Gravity/Soda/Labyrinth) + ColorRush streak×N; nhạc nền per-mode (map 3 track) — verify device xong.
>
> 🟢 **Đợt 2 (2026-07-07) — Mở-màn animation + luật thắng + audio cue xong (code+test xanh):**
> - **Mở-màn đặc trưng**: `_modeSpec` thêm `icon`/`motion` (enum `ModeIntroMotion`: shake/spin/pulse/
>   riseFade/bounce/none — 12 mode nhóm vào 5 archetype tái dùng, không viết 12 transform riêng).
>   `_ModeIntroOverlay` bọc Icon trong `Transform` dùng lại `AnimationController` 1.3s sẵn có (không thêm
>   controller mới); tôn trọng `reducedMotion` (fallback về `none`).
> - **Luật thắng 1 dòng**: `_modeSpec.ruleKey` + getter `modeRuleKey`; overlay hiện subtitle nhỏ dưới
>   label. 12 key `rule_*` (en/vi + `_w252ByLang` 20 ngôn ngữ theo convention `_wXXByLang`).
> - **Audio cue riêng**: Boss `playSpecial()` khi phản đòn; Survival `playNote(24)` khi nước dâng ≥75%
>   (hysteresis tránh spam quanh ngưỡng); Rhythm đã có sẵn từ trước (khoá theo beat).
> - **Test** `test/w25_2_mode_contrast_test.dart` thêm `modeIntroIcon`/`modeRuleKey`. `flutter analyze`
>   0 · full suite (exclude slow) xanh. 🚫 chưa commit — user tự commit ([[code-on-main-only]]).
> - **Verify device (2026-07-07, Pixel 7 Pro)**: build+install+run debug APK thật, stress-swipe Boss
>   (chuyển Giai Đoạn 2 → path `playSpecial()` phản đòn chạy), Gravity (path icon `south_rounded`/
>   spin chạy), Survival chơi tới tràn nước 100% (path `_survivalDangerCueFired` hysteresis 0.75/0.6
>   chạy hết, dialog "Ngập Rồi!" đúng). Full logcat buffer ~10 phút touch input thật: 0
>   `FATAL EXCEPTION`/`ANR`/`E/flutter` — chỉ noise OS-level không liên quan app.

# Phase 2 — Mỗi mode một "identity", không thấy cùng một game

Hướng user (3): "mọi mode giống nhau vì cùng core match-3". Đúng — nhưng chữa bằng **tương phản
cảm giác**, không phải thêm cơ chế. Cùng engine mà *cảm thấy* khác là đủ. Rủi ro thấp (phần lớn
là HUD / audio / palette / luật thắng, ít đụng logic lõi).

## Việc (mỗi mode có ≥2 tín hiệu nhận diện riêng)
- [x] **Palette / theme per-mode**: Boss tối + đỏ đe doạ; Rhythm neon nhịp; Survival lạnh + nước
  dâng; Labyrinth tối + fog. Hiện theme chủ yếu theo world — thêm override theo mode.
- [x] **HUD riêng biệt**: mỗi mode nhấn 1 chỉ số chủ đạo (Boss=thanh máu to; Rhythm=beat bar;
  Survival=tide indicator; ColorRush=streak ×). Tránh HUD "điểm + lượt" đồng phục.
- [x] **Audio cue riêng**: nhịp/tempo/motif khác theo mode (tận dụng `playMelodic`/`audio_manager`).
  Boss có sting phản đòn; Rhythm khoá theo BPM; Survival nhạc căng khi nước cao.
- [x] **Luật thắng/thua "đọc được ngay"**: câu 1 dòng + micro-anim mở màn nói rõ "mode này thắng bằng
  gì" (nhiều mode hiện chỉ khác target số).
- [x] **Mở màn 1.5s** đặc trưng mỗi mode (không phải cùng 1 fade) để "đóng khung" trải nghiệm.

## Acceptance
- [x] Chụp màn 4-5 mode cạnh nhau → **phân biệt được mode chỉ bằng ảnh tĩnh** (không đọc chữ) — verify
  device đợt 1 (palette) + [[w26-1-mode-contrast-hud-audio]] (HUD, 5 mode chụp cạnh nhau).
- [x] Cờ "Giảm hiệu ứng động" vẫn tôn trọng (tắt slow-mo/shake, palette vẫn đổi OK) — icon motion đợt 2
  cũng fallback `none` khi `reducedMotion`.
- [x] Không regress FPS; `flutter analyze` 0; widget test HUD-per-mode mount đúng nhánh — analyze 0 +
  full suite xanh đợt 2; widget test HUD ở `test/w26_1_mode_hud_test.dart`.

## Lưu ý
- Phần lớn ở tầng render/HUD/audio → an toàn, làm được **không cần device** (verify feel thì cần).
- Key i18n cho câu-luật-thắng mới → convention `_wXXByLang`.
- Đây là phase "đòn bẩy cao nhất trên mỗi giờ công" cho cảm giác sơ sài — ưu tiên sau Phase 1.
