---
id: w4-daily-reward
title: Daily Reward
wave: 4
status: done
owner: claude
---

# Daily Reward (phần thưởng đăng nhập hằng ngày)

## Mục tiêu
Tạo lý do quay lại app mỗi ngày → tặng xu theo chuỗi (streak).

## Thiết kế
- **Storage**: `dailyLastClaim` (epoch-day int), `dailyStreak` (int).
- **GameController**:
  - `int get _todayEpochDay` (từ `DateTime.now()`).
  - `bool canClaimDaily` — chưa nhận hôm nay.
  - `RxInt dailyStreak`.
  - `int dailyRewardFor(int streakDay)` — 20 + (day-1)*10, cap 100 (chu kỳ 7 ngày).
  - `int claimDaily()` — cộng xu, cập nhật streak (liên tục → +1, gãy → reset 1), lưu, trả số xu.
- **UI**: HomeScreen có nút/badge "DAILY" (chấm sáng khi có quà). Bấm → **overlay trong cây** (route dialog no-op, theo [[route-dialogs-noop-fullscreen]]) hiện 7 ô ngày + nút NHẬN.

## Acceptance
- [x] claimDaily cộng đúng xu + tăng streak liên ngày, reset khi gãy
- [x] không nhận 2 lần/ngày
- [x] overlay hiện đúng, nhận xong badge tắt
- [x] unit test cho logic streak/reward
- [x] i18n key (en/vi + fallback)
- [x] analyze 0 issue · test pass

## ✅ Kết quả
Hoàn thành Wave 4 — analyze 0 issue · 89 test pass · build APK debug OK.
