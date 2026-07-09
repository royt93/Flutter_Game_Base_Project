# Release Checklist — Neon Jewels

Phần **tự động** đã được CI/script phủ (xem cuối). File này liệt kê phần **bản chất phải
kiểm tay** trên thiết bị thật trước khi ký release. Tick hết → an tâm lên store.

## A. Tự động (đã xanh — chỉ cần chạy lại trên nhánh release)

- [x] `flutter analyze` → 0 issue ✅ _(2026-06-25, nhánh chore/release-hardening-qc)_
- [x] `flutter test --exclude-tags slow` → all pass (731) ✅
- [x] `flutter test integration_test/ -d <device>` → 15 pass (Wave5 + TC-12 slow) ✅ _(Redmi bbcf4c4b)_
- [ ] `tool/release_device_gate.sh <serial>` → install + launch + logcat sạch _(chưa chạy script; đã làm tay tương đương: install fresh + launch + logcat sạch ✅)_
- [x] Build release: `flutter build apk --release` (69.3MB) **và** `flutter build appbundle --release` (62.0MB) → pass ✅
- [ ] Smoke AAB (đúng định dạng Play Store):
      `bundletool build-apks --bundle=...aab --connected-device --device-id=<serial>` →
      `bundletool install-apks` → launch → logcat sạch

> **Lưu ý automation gameplay:** dùng `integration_test/` (Dart-driven) để drive gameplay,
> KHÔNG dùng script uiautomator. Đã bỏ `tool/device_gameplay_all_modes.sh` vì game có
> animation Flame chạy liên tục → `uiautomator dump` luôn báo `could not get idle state`,
> không lấy được cây node. integration_test không phụ thuộc idle/semantics nên là cách đúng.

## B. Kiểm tay — không tự động hoá được

### B1. Update / Migration (P0 — cần BẢN CŨ thật)
> Automation chỉ kiểm `install -r` cùng version. Migration thật cần version cũ → kiểm tay.
- [ ] Cài bản **release đang phát hành** (version cũ), tạo progress: unlock level, stars, coins, booster, side-mode records
- [ ] `adb install -r app-release.apk` (bản mới) — KHÔNG uninstall
- [ ] Mở lại: unlock/stars/coins/booster/records **còn nguyên**, không force reset
- [ ] Shard/giá trị migrate (nếu có) chỉ chạy **1 lần**, restart không farm thêm
- [ ] Battle Pass / Season / Achievement / Collection / Temple / Tree / Card không mất/nhân đôi

### B2. Localization (22 locale)
- [ ] Lần lượt đổi 22 ngôn ngữ trong Settings → app đổi ngay, không crash
- [ ] Home/Game/Shop/Guide/Settings: không lộ raw key (`boss_title`, `btn_home`…)
- [x] Arabic `ar_SA`: không mất ký tự, layout không vỡ nghiêm trọng ✅ _(RTL mirror đúng toàn UI — verified)_
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

- [ ] **Chơi ~10 phút Campaign** — soi song song: `adb -s <serial> logcat | grep -iE "ANR|Choreographer.*Skipped [0-9]{3}"`
      **Pass:** không ANR, không "Application not responding", không giật rõ khi cascade.
- [ ] **Background ↔ Resume khi đang chơi** (Campaign/**Rush**/Survival) — `adb -s <serial> shell input keyevent KEYCODE_HOME` → chờ 30s → mở lại.
      **Pass:** state đúng (không reset bàn), timer không nhảy bậy (nhất là Rush/Survival), audio không kẹt/chồng.
- [ ] **Combo lớn liên tục** — tạo chuỗi cascade dài / kết hợp nhiều special gem.
      **Pass:** không lag rõ, audio không chồng tiếng (24 nốt combo + special).

### B5. Store / Build sanity
- [ ] Version footer khớp `pubspec.yaml` + build number
- [ ] App icon / splash trên launcher đúng brand (không icon default)
- [ ] Package id = `com.galaxyjoy.neon_jewels`
- [ ] AAB ký bằng **upload key** đúng (Play App Signing)
- [ ] Store listing: mô tả, screenshot, phân loại nội dung, chính sách quyền riêng tư
- [ ] **Quảng cáo**: nếu có ad SDK, kiểm ad không che UI/không chặn input (hiện pubspec KHÔNG có ad SDK)

## C. Reset progress (P0)
- [x] Settings → Reset → Cancel: không đổi data ✅ _(2026-07-09, device 2B051FDH3006MU — 5 mạng/10.385 xu/badge Thành Tựu giữ nguyên)_
- [x] Settings → Reset → Confirm: mọi hệ về fresh, không badge stale ✅ _(2026-07-09 — coin 10.385→10.000, badge Thành Tựu tắt, World Map chỉ node 1 mở/0 sao; starter booster x2 xuất hiện lại là default `getInt(..., def: 2)` khi key bị xoá — đúng ý đồ, không phải sót data cũ)_
- [x] Restart app: vẫn fresh (force-stop + relaunch, coin vẫn 10.000 không lộ lại 10.385, tutorial "Chào Mừng" hiện lại) ✅. Level 1 vào chơi được, không khoá, HUD/target/lượt đúng ✅ — **chưa verify được swap/earn/claim thật** vì `adb input swipe/tap` không kích hoạt Flame's gesture detector (không phải máy hỏng — xem ghi chú automation trong đầu file); cần chơi tay thật hoặc chạy `integration_test/` để chốt nốt phần earn/claim.
