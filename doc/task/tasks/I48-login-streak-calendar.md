# I48 — Login Streak Calendar

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Could · **Deps:** không

## Mục tiêu

Thêm 1 lịch điểm danh 7 ngày (hiển thị trong 1 dialog, mở từ home screen)
— mỗi ngày mở app (tính theo epoch-day UTC, chống gian lận qua chỉnh giờ
máy) tự động cộng 1 vào streak liên tục nếu ngày hôm nay = ngày trước đó
+1; nếu bỏ lỡ ≥1 ngày, streak reset về 1. Ngày thứ 3/5/7 trong chu kỳ
thưởng xu tăng dần (vd 20/40/100), yêu cầu người chơi bấm nút "nhận
thưởng" (không tự động cộng ngầm) — sau khi nhận, ngày đó đánh dấu đã
nhận trong chu kỳ hiện tại. Qua ngày thứ 8 thì vòng lặp lại từ ngày 1.

## Vì sao

Game hiện có Daily Challenge (F13) và Daily Spin (I6/season) nhưng cả 2
đều là "làm 1 việc trong ngày để nhận thưởng 1 lần", không có khái niệm
"chuỗi liên tục" khuyến khích quay lại mỗi ngày liên tiếp — cơ chế phổ
biến trong game casual để tăng retention hàng ngày. Tái dùng trực tiếp
`GameController._todayEpochDay()` (đã có sẵn, chống lùi giờ máy) theo
đúng convention `currentSeasonIndex`/daily-spin/daily-challenge.

## Acceptance criteria

- [ ] `GameController` thêm state: `RxInt loginStreakCount`, `RxInt
  loginStreakClaimableDay` (ngày trong chu kỳ 1-7 hiện có thể nhận, 0 nếu
  đã nhận hết cho ngày hôm nay), khởi tạo từ storage trong `onInit`.
- [ ] Mỗi lần app mở tới home screen (gọi 1 lần trong
  `GameController.onInit` hoặc 1 method `checkLoginStreak()` gọi từ
  `home_screen.dart.initState`): so `_todayEpochDay()` với
  `StorageKeys.lastLoginEpochDay` — nếu chênh lệch = 1 → `loginStreakCount
  += 1`; nếu chênh lệch = 0 → không đổi gì (đã tính ngày này rồi); nếu
  chênh lệch > 1 → reset `loginStreakCount = 1`. Luôn ghi
  `StorageKeys.lastLoginEpochDay = _todayEpochDay()` sau khi tính (kể cả
  khi = 0, để tránh gọi lại nhiều lần trong cùng ngày làm sai lệch —
  nhưng vì chênh lệch=0 không đổi streak nên ghi lại giá trị cũ là an
  toàn, không cần guard riêng).
- [ ] Ngày trong chu kỳ = `(loginStreakCount - 1) % 7 + 1` (1..7, lặp lại
  mỗi 7 ngày liên tục, không phụ thuộc ngày trong tuần thực tế).
- [ ] Thưởng chỉ ở ngày chu kỳ 3/5/7 (20/40/100 xu) — các ngày còn lại
  không có nút nhận, chỉ hiển thị đã điểm danh.
- [ ] Nhận thưởng: cộng `coins`, lưu bitmask
  `StorageKeys.loginStreakClaimedMask` (bit tương ứng ngày chu kỳ đã
  nhận, reset về 0 khi bắt đầu chu kỳ 7-ngày mới tức khi
  `(loginStreakCount - 1) % 7 == 0` và `loginStreakCount > 1`).
- [ ] Không thể nhận trùng trong cùng chu kỳ (nút disable/ẩn nếu bit đã
  set).
- [ ] Dialog hiển thị 7 ô ngày, ô hiện tại highlight, ô có thưởng hiện số
  xu, ô đã qua hiện dấu tick.
- [ ] Unit test `test/logic/login_streak_test.dart` (pure function nhận
  `previousEpochDay`, `todayEpochDay`, `previousStreak` → trả `newStreak`):
  liên tục (+1) tăng streak, cùng ngày giữ nguyên, bỏ lỡ (>1 ngày) reset
  về 1; test riêng cho việc reset `claimedMask` đúng lúc bắt đầu chu kỳ
  mới.
- [ ] i18n đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Logic tính streak nên tách thành pure function trong `lib/data/`
  (vd `lib/data/login_streak.dart`, hàm `int nextLoginStreak(int
  previousEpochDay, int todayEpochDay, int previousStreak)`) — nhận
  `epochDay` làm tham số thay vì tự gọi `DateTime.now()`, để test
  được và để `GameController` là nơi duy nhất gọi
  `_todayEpochDay()` rồi truyền vào, đúng pattern
  `generateDailyChallengeGrid(_todayEpochDay())`.
- `StorageKeys` mới (thêm sau `bossRushBestStreak`): `loginStreakCount`,
  `lastLoginEpochDay`, `loginStreakClaimedMask`.
- Vì đây là method mới trên `GameController` (không phải import 1 helper
  đứng riêng), gọi `_todayEpochDay()` trực tiếp bên trong — không cần
  export method này ra ngoài class.

DoD chung: `../README.md`.
