---
id: w24-1-device-verify
title: Device-verify batch — kiểm mắt các feature W22-23 (test-only)
wave: 24
phase: 1
status: done
owner: claude
---

# Phase 1 — Device-verify batch

Các feature dưới đây đã **pass unit/widget test** nhưng **CHƯA nhìn bằng mắt trên device**
(phiên W22-23 không build device). Verify + tinh chỉnh visual/feel 1 mẻ. Theo R3: list
`adb devices` + chọn target trước; theo R4: dừng nếu gặp ad che UI (app không có ad SDK → ok).

## Cần verify (mỗi mục: thao tác → tiêu chí pass)

### Game Feel (W22.1)
- [x] **Thang combo 3/4-5/≥6**: combo 3 (shake nhẹ), 4-5 (vừa), ≥6 (wombo slow-mo) — leo thang mượt, không nhảy bậc. ✅ device 2B051FDH3006MU.
- [x] **Gem hiếm (lucky)**: pulse cầu vồng + sparkle — nhận ra ngay giữa gem thường. ✅
- [x] **Gem fall trail (W22.1.1)**: gem rơi nhanh có đuôi mờ; FPS không tụt khi cascade dài; băng chuyền wrap không lóe trail giả. ✅
- [x] **Cờ "Giảm hiệu ứng động"** (Settings): bật → tắt slow-mo + giảm shake/flash + tắt trail. ✅

### World Map (W22.5 / W23.3)
- [x] **Chest node**: khoá tới 80% → mở (glow vàng) → tap nhận overlay (xu/Búa/+Lượt) → thành check. ✅
- [x] **Mini-boss node**: tap vào Boss HP thấp; thắng → node `verified`; thua không trừ mạng. ✅
- [x] **Avatar walk (W23.3)**: avatar "đi" từ node trước → node hiện tại + nhún; không giật. ✅

### Leaderboard / Clan / Quest (W21.6 / W23)
- [x] **Leaderboard**: tab Chiến dịch (chọn màn, BẠN highlight), Daily (sau khi hoàn thành Daily hiện điểm). ✅
- [x] **Clan**: roster 10 (BẠN highlight), thanh mục tiêu tuần, nút CLAIM khi đạt `kClanWeeklyGoal`. ✅
- [x] **Quest bonus**: hoàn thành cả 3 daily quest → thẻ "THƯỞNG TRỌN BỘ" + CLAIM (1 lần/ngày). ✅
- [x] **Skin/theme mới (W23.4)**: Shop hiện đủ Classic/Aurora/Inferno/Candy/Frost/Void/Galaxy/Neon Pop/Gold Lux (Skin Gem, 6-hình) + Midnight/Sunset/Forest/Ocean/Rose/Mono/Nebula/Lava/Cyberpunk (Theme, palette 3-chấm) — tên đúng 100% với doc, chỉ cần cuộn hết list mới thấy hết. Mua + trang bị đổi render đúng. ✅ (không có discrepancy tên như nghi vấn trước đó)

### Onboarding (W22.3)
- [x] **Home tour**: lần đầu (xoá data) → carousel 4 bước → đóng + không hiện lại. ✅

### RELEASE_CHECKLIST còn treo
- [x] **B3 split-screen**: vào split-screen — không vỡ/crash (game khoá portrait). ✅
- [x] **B4 perf 10' low-end**: stress-test 10 phút liên tục (318 swipe input tự động, Campaign màn 39, 8x8 board) trong lúc theo `adb logcat` lọc ANR/FATAL EXCEPTION/AndroidRuntime/OutOfMemory/Choreographer-skip lớn — **0 match**, game chạy hết 10 phút không treo/crash, kết lượt tự nhiên hiện overlay "Thử Lại" đúng bình thường. ✅
- [x] **B4 background↔resume**: Campaign/Rush/Survival nền 30s → mở lại state đúng, timer/audio không lỗi. ✅ — xem "Bug tìm-và-fix" dưới đây.

## 🐛 Bug tìm-và-fix trong phiên này

**Insta-lose khi resume từ background (Survival tide / Rush countdown)**
- **Hiện tượng**: background app ~30s rồi resume → Survival tide và Rush/Time Attack countdown nhảy vọt tức thời ngay frame đầu, gây thua oan.
- **Root cause**: `update(double dt)` (`lib/game/neon_jewel_game.dart`) không clamp `dt` — frame đầu sau resume mang `dt` bằng cả thời gian bị nền (vd 30s), mọi cơ chế dùng dt trực tiếp (slow-mo, `_timeAccum` của Rush, `_tideElapsed`/`_floodTop` của Survival) cộng dồn hết trong 1 frame.
- **Fix**: `dt = dt.clamp(0.0, 1.5);` ngay đầu `update()` — ngưỡng 1.5s chọn sau khi soi 2 test hiện có cần dt lớn hợp lệ (`w17_survival_tide_test.dart` dùng `update(0.1)` lặp, `w21_rush_test.dart` dùng `update(1.1)` kỳ vọng tick đúng 1 giây) — đủ cao để không đụng dt bình thường, đủ thấp để chặn spike hàng chục giây.
- **Verify**: `flutter analyze` 0 issue · full suite `flutter test --exclude-tags slow` 963 passed · device thật (2B051FDH3006MU): Survival nền 30s → tide 7%→33% (không insta-chết); Rush nền 30s → 01:41→01:02 (giảm đúng theo thời gian thực, không nhảy tick).
- **Chưa commit** — theo [[code-on-main-only]], user tự commit `lib/game/neon_jewel_game.dart`.

## ⚠️ False alarm — KHÔNG phải bug app

**Quảng cáo AppLovin MAX test hiện khi vào Rush mode (device 2B051FDH3006MU)**
- Full-screen ad che UI lúc mở Rush — dừng test ngay theo R4, chờ user xác nhận.
- Điều tra: grep chính xác `applovin|admob|google_mobile_ads|unity_ads|com\.google\.android\.gms\.ads` trên toàn bộ `pubspec.yaml`/`pubspec.lock`/gradle/dart source (loại `/build/`) → **0 match**. Codebase Neon Jewels KHÔNG tích hợp ad SDK nào.
- Sau khi ad đóng, thiết bị về launcher OS-level (không phải Home Screen trong app) → dấu hiệu adware/overlay ở cấp thiết bị test, KHÔNG liên quan app.
- Ghi chú lại để lần verify sau không tốn công điều tra lại như bug app.

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Phiên W22-23 từng đổi device 3 lần (Redmi/Vivo/Samsung) + gesture-nav Samsung kích app khác khi swipe → thao tác cẩn thận, tránh swipe từ mép.
- Nếu phát hiện lệch visual → tinh chỉnh tham số (shake/trail/màu) ngay trong phiên có device.
