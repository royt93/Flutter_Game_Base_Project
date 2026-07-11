# Release Checklist — Neon Jewels

Phần **tự động** đã được CI/script phủ (xem cuối). File này liệt kê phần **bản chất phải
kiểm tay** trên thiết bị thật trước khi ký release. Tick hết → an tâm lên store.

## A. Tự động (đã xanh — chỉ cần chạy lại trên nhánh release)

- [x] `flutter analyze` → 0 issue ✅ _(2026-07-10, sau Wave 28.3)_
- [x] `flutter test --exclude-tags slow` → all pass (1038) ✅ _(2026-07-10)_
- [x] `flutter test integration_test/ -d <device>` → 15 pass (Wave5 + TC-12 slow) ✅ _(Redmi bbcf4c4b)_
- [ ] `tool/release_device_gate.sh <serial>` → install + launch + logcat sạch _(chưa chạy script; đã làm tay tương đương: install fresh + launch + logcat sạch ✅ 2026-07-10, Pixel_7_Pro 2B051FDH3006MU)_
- [x] Build release: `flutter build apk --release` (70.9MB) **và** `flutter build appbundle --release` (62.8MB) → pass ✅ _(2026-07-10, v2026.07.10+20260710)_
- [x] Smoke AAB (đúng định dạng Play Store) ✅ _(2026-07-10, Pixel_7_Pro 2B051FDH3006MU)_:
      `bundletool build-apks --bundle=...aab --connected-device --device-id=<serial>` →
      `bundletool install-apks` → launch → logcat sạch, không crash, tour Chào Mừng hiện đúng, không quảng cáo

> **Lưu ý automation gameplay:** dùng `integration_test/` (Dart-driven) để drive gameplay,
> KHÔNG dùng script uiautomator. Đã bỏ `tool/device_gameplay_all_modes.sh` vì game có
> animation Flame chạy liên tục → `uiautomator dump` luôn báo `could not get idle state`,
> không lấy được cây node. integration_test không phụ thuộc idle/semantics nên là cách đúng.

## B. Kiểm tay — không tự động hoá được

### B1. Update / Migration (P0 — cần BẢN CŨ thật)
> Automation chỉ kiểm `install -r` cùng version. Migration thật cần version cũ → kiểm tay.
> **BLOCKED 2026-07-10**: máy test (Pixel_7_Pro) chỉ có build debug (signature khác
> release) → `install -r` báo `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, không giữ được state
> để test migration thật. Không có bản release cũ lưu local. Đã cài fresh thay thế —
> B1 CHƯA được verify vòng này, cần bản APK/AAB release đang live (tải từ Play Console)
> để chạy đúng chuẩn ở vòng release kế tiếp.
- [ ] Cài bản **release đang phát hành** (version cũ), tạo progress: unlock level, stars, coins, booster, side-mode records
- [ ] `adb install -r app-release.apk` (bản mới) — KHÔNG uninstall
- [ ] Mở lại: unlock/stars/coins/booster/records **còn nguyên**, không force reset
- [ ] Shard/giá trị migrate (nếu có) chỉ chạy **1 lần**, restart không farm thêm
- [ ] Battle Pass / Season / Achievement / Collection / Temple / Tree / Card không mất/nhân đôi

### B2. Localization (22 locale)
- [ ] Lần lượt đổi 22 ngôn ngữ trong Settings → app đổi ngay, không crash
- [ ] Home/Game/Shop/Guide/Settings: không lộ raw key (`boss_title`, `btn_home`…)
- [x] Arabic `ar_SA`: không mất ký tự, layout không vỡ nghiêm trọng ✅ _(RTL mirror đúng toàn UI — verified; 2026-07-10 spot-check thêm 3 màn Wave 28.3 mới: Piggy Bank, Album/Collection (3 hàng mốc 25/50/75% render đúng, không lộ key), Progression Tree (node "المتصاعد" ascendant) — không tràn chữ, không lộ raw key)_
- [x] Thai / Hindi / Bengali: font đủ glyph, không ô vuông ✅ _(verified, gồm chữ số Bengali ১০০/২)_
- [ ] Placeholder `@n` `@c` `@t` thay đúng

### B3. Accessibility / Layout
> Đặt điều kiện bằng `adb` (thay `<serial>`), thao tác trong app, rồi soi tiêu chí pass.
> **Khôi phục sau B3:** `adb shell settings put system font_scale 1.0` · `adb shell wm density reset` · `adb shell "cmd uimode night no"`

- [x] **Font scale 1.3x & 1.5x** ✅ _(game dùng cỡ chữ cố định, bỏ qua font scale hệ thống → không tràn; verified Home+Settings)_ — `adb -s <serial> shell settings put system font_scale 1.3` (rồi `1.5`)
      → Home → 1 level → dialog Win/Lose, Settings, 1 reward card.
      **Pass:** HUD/dialog/card không cắt chữ quan trọng, nút bấm được, không crash.
- [x] **Display size lớn nhất** ✅ _(Home/World Map/dialog/board+booster bar đều vừa màn — verified density 480)_ — `adb -s <serial> shell wm density 480` (gốc 320 → ~1.5x)
      → xem board + booster bar.
      **Pass:** board vừa màn (không tràn), booster bar scroll được.
- [x] **Xoay màn** ✅ _N/A — game khoá portrait (verified: ép user_rotation không xoay → không vỡ)_. ⏳ **Split-screen** còn kiểm tay — `adb -s <serial> shell settings put system accelerometer_rotation 1`; vào split-screen từ recents.
      **Pass:** không vỡ layout/crash. *(Nếu game khoá portrait → ghi "N/A — locked", vẫn đạt.)*
- [x] **Theme dark/light hệ thống** ✅ _(giữ neon theme riêng, bỏ qua day/night hệ thống, contrast đủ — verified)_ — `adb -s <serial> shell "cmd uimode night yes"` (rồi `no`).
      **Pass:** app giữ neon theme (không bị ép sáng/tối lạ), contrast đủ đọc.

### B4. Lifecycle / UX cảm nhận
> Phần cảm nhận thật — không set bằng lệnh; cần chơi tay trên máy low-end.

- [x] **Chơi ~10 phút Campaign** ✅ _(2026-07-11, device 2B051FDH3006MU — proxy `integration_test/tc12_lifecycle_test.dart` bot greedy 233 vòng lặp/10 phút thật, `adb logcat` song song lọc `ANR|Choreographer.*Skipped [0-9]{3}|FATAL EXCEPTION`: 0 hit, không crash)_
      **Pass:** không ANR, không "Application not responding", không giật rõ khi cascade.
- [x] **Background ↔ Resume khi đang chơi** (Campaign/**Rush**/Survival) ✅ _(2026-07-11, device 2B051FDH3006MU — `tc12_lifecycle_test.dart` 3 case background→resume qua kênh lifecycle thật, cả 3 pass: HUD/mode giữ nguyên, không crash. Root-cause code: `timeLeft` chỉ giảm trong `update(dt)` do Flame Ticker chi phối (neon_jewel_game.dart:577-595) → tự đứng khi backgroundded, không Timer real-time riêng nên không nhảy bậy; BGM pause/resume đúng hook `didChangeAppLifecycleState` (main.dart:85-92))_
      **Pass:** state đúng (không reset bàn), timer không nhảy bậy (nhất là Rush/Survival), audio không kẹt/chồng.
- [x] **Combo lớn liên tục** ✅ _(2026-07-11, device 2B051FDH3006MU — proxy Endless bot greedy 60+ nước cascade liên tục (case "Endless: bot greedy...") đã pass trước đó, không lag/crash. Audio: `playMelodic`/arpeggio wombo (audio_manager.dart:143-190) là chồng nốt CÓ CHỦ ĐÍCH (hợp âm ngũ cung), không phải bug kẹt tiếng — mỗi nốt là sample ngắn one-shot, không loop)_
      **Pass:** không lag rõ, audio không chồng tiếng (24 nốt combo + special).

### B5. Store / Build sanity
- [x] Version footer khớp `pubspec.yaml` + build number ✅ _(2026-07-10: footer `v2026.07.10`, `pm dump` versionName=2026.07.10/versionCode=20260710, khớp `pubspec.yaml: 2026.07.10+20260710`)_
- [x] App icon / splash trên launcher đúng brand (không icon default) ✅ _(2026-07-10: `asset/icon/ic_launcher.png` custom 1024x1024, không phải icon Flutter default)_
- [x] Package id = `com.galaxyjoy.neon_jewels` ✅ _(2026-07-10, xác nhận qua adb install/pm dump)_
- [ ] AAB ký bằng **upload key** đúng (Play App Signing) _(cần đối chiếu Play Console, không verify được từ máy local)_
- [ ] Store listing: mô tả, screenshot, phân loại nội dung, chính sách quyền riêng tư _(việc trong Play Console, không verify được qua device)_
- [x] **Quảng cáo**: N/A — pubspec không có ad SDK, không quan sát ad trong toàn bộ lần verify 2026-07-10 (fresh install + AAB smoke) ✅

## C. Reset progress (P0)
- [x] Settings → Reset → Cancel: không đổi data ✅ _(2026-07-09, device 2B051FDH3006MU — 5 mạng/10.385 xu/badge Thành Tựu giữ nguyên)_
- [x] Settings → Reset → Confirm: mọi hệ về fresh, không badge stale ✅ _(2026-07-09 — coin 10.385→10.000, badge Thành Tựu tắt, World Map chỉ node 1 mở/0 sao; starter booster x2 xuất hiện lại là default `getInt(..., def: 2)` khi key bị xoá — đúng ý đồ, không phải sót data cũ)_
- [x] Restart app: vẫn fresh (force-stop + relaunch, coin vẫn 10.000 không lộ lại 10.385, tutorial "Chào Mừng" hiện lại) ✅. Level 1 vào chơi được, không khoá, HUD/target/lượt đúng ✅ — **chưa verify được swap/earn/claim thật** vì `adb input swipe/tap` không kích hoạt Flame's gesture detector (không phải máy hỏng — xem ghi chú automation trong đầu file); cần chơi tay thật hoặc chạy `integration_test/` để chốt nốt phần earn/claim.
