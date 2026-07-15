# F2 — Daily reward + streak

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** — 

## Mục tiêu
Mỗi ngày mở app lần đầu → nhận thưởng xu; chuỗi ngày liên tiếp (streak) tăng
phần thưởng theo mốc (D1..D7 rồi lặp). Bỏ lỡ 1 ngày → reset streak.

## Vì sao
Lever retention kinh điển cho casual. Kéo người chơi quay lại đều.

## Acceptance criteria
- [x] Lần mở đầu tiên trong ngày (theo `todayEpochDay`) → dialog nhận thưởng.
- [x] Streak +1 nếu hôm nay = hôm nhận cuối +1 ngày; reset về 1 nếu cách >1 ngày.
- [x] Đã nhận hôm nay → không cho nhận lại (kể cả restart app).
- [x] **Anti-cheat time:** dùng max-epoch-day-đã-thấy; chỉnh lùi đồng hồ KHÔNG cho nhận thêm.
- [x] Unit test: nhận/không-nhận theo ngày, tăng/reset streak, chống lùi giờ.

## Rà soát checkbox (2026-07-13)
- `lib/presentation/controllers/game_controller.dart`: `canClaimDaily` (so `_todayEpochDay()` với `lastClaimDay`), `claimDaily()` cộng streak (+1 nếu liên tiếp, về 1 nếu gián đoạn) + `dailyRewards` bảng thưởng; `_todayEpochDay()` dùng `maxEpochDaySeen` (chống lùi giờ).
- `lib/presentation/screens/home_screen.dart`: `initState` gọi `_showDailyRewardDialog` khi `gameCtrl.canClaimDaily`.
- `test/presentation/game_controller_test.dart`: có test claim ngày đầu (streak=1), không cho claim lại trong ngày, streak+1 khi liên tiếp, reset về 1 khi cách >1 ngày, và test chỉnh đồng hồ về tương lai rồi lùi lại không cho claim thêm (dòng ~124-179).
- `resetProgress()` xoá cả 3 key `lastClaimDay`/`dailyStreak`/`maxEpochDaySeen`.

## Subtasks (gợi ý file)
1. `lib/core/storage_service.dart`: thêm keys `lastClaimDay`, `streak`, `maxEpochDaySeen`.
2. `lib/core/` helper `todayEpochDay` (max epoch-day từng thấy) — chống gian lận giờ.
3. Controller mới `DailyController` (permanent) hoặc gộp vào GameController: `canClaim`,
   `claim()` cộng xu + cập nhật streak.
4. UI: dialog `NeonDialog` nhận thưởng (7 ô mốc, ô hôm nay sáng) + mascot happy.
5. Trigger ở `HomeScreen` khi build nếu `canClaim`.
6. Test: `test/presentation/daily_reward_test.dart`.

## Ghi chú kỹ thuật
Bảng thưởng vd `[50,80,120,160,200,260,400]` xu. Wire `resetState` vào `resetProgress`.

DoD chung: `../README.md`.
