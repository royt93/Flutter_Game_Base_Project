# I50 — Weekly Goal Card

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Could · **Deps:** không

## Mục tiêu

1 thẻ mục tiêu tuần (hiển thị trong dialog riêng, mở từ home screen): mỗi
tuần (theo `epochDay ~/ 7`, tuần mới bắt đầu mỗi 7 ngày kể từ epoch, không
cần khớp lịch dương thực tế) hệ thống ra 1 mục tiêu cá nhân cố định — vd
"pop tổng 300 gem trong tuần này" — theo dõi tiến độ cộng dồn xuyên suốt
mọi mode (campaign + side-mode), khi đạt đủ, người chơi bấm nhận thưởng
xu 1 lần. Qua tuần mới, mục tiêu reset về 0 và target có thể đổi.

## Vì sao

Khác I38 Weekly Featured Level (đã có, spec-only, chọn 1 level cụ thể làm
"nổi bật trong tuần") — I50 là 1 quầy tiến độ **cá nhân, cộng dồn qua mọi
trận**, không gắn với 1 level cụ thể nào, hướng ngắn hạn hơn Prestige
(I27, theo mùa/season) và không cần leaderboard (đã xác nhận
`lib/logic/leaderboard.dart` không có sẵn cơ chế "quầy mục tiêu tuần" nào
tương tự). Tạo thêm 1 lý do quay lại đều trong tuần, bổ trợ I48 (theo
ngày) ở tầng theo tuần.

## Acceptance criteria

- [ ] `GameController` thêm `RxInt weeklyGoalProgress`, hằng số
  `weeklyGoalTarget = 300` (gems), khởi tạo từ storage trong `onInit`.
- [ ] Mỗi khi 1 nhóm màu bị pop (bất kỳ mode nào, kể cả side-mode), cộng
  `group.length` vào `weeklyGoalProgress` — hook tại đúng điểm
  `pop_star_game.dart` đã gọi `controller.addScore(...)` (thêm 1 lệnh gọi
  song song `controller.addWeeklyGoalProgress(group.length)`).
- [ ] Đầu mỗi lần app tính lại tuần hiện tại
  (`currentWeekIndex = _todayEpochDay() ~/ 7`): nếu khác
  `StorageKeys.weeklyGoalWeek` đã lưu → reset `weeklyGoalProgress = 0`,
  reset trạng thái đã nhận thưởng, lưu `weeklyGoalWeek` mới.
- [ ] Khi `weeklyGoalProgress >= weeklyGoalTarget`: hiện nút nhận thưởng
  (100 xu); bấm 1 lần, đánh dấu
  `StorageKeys.weeklyGoalClaimedWeek = currentWeekIndex` (chống nhận 2
  lần trong cùng tuần); tiến độ vẫn hiển thị (không reset ngay, chỉ reset
  khi sang tuần mới).
- [ ] Dialog hiển thị thanh tiến độ `progress/target`, nút nhận thưởng
  (disable nếu chưa đủ hoặc đã nhận).
- [ ] Unit test `test/logic/weekly_goal_test.dart` (pure function nhận
  `previousWeek, currentWeek, previousProgress` → trả `progress` sau khi
  xử lý reset-nếu-sang-tuần-mới): tuần không đổi giữ nguyên tiến độ, tuần
  đổi reset về 0; test riêng cho việc chặn nhận thưởng 2 lần cùng tuần.
- [ ] i18n đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Pure logic (tính reset theo tuần) đặt trong `lib/data/weekly_goal.dart`
  — nhận `epochDay` làm tham số (do `GameController._todayEpochDay()`
  cung cấp), theo đúng convention `epochDay ~/ 7` để phân tuần (giống
  cách `currentSeasonIndex` dùng `_todayEpochDay() ~/ seasonLengthDays`).
- `StorageKeys` mới: `weeklyGoalProgress`, `weeklyGoalWeek`,
  `weeklyGoalClaimedWeek`.
- Không phân biệt mode khi cộng tiến độ (campaign lẫn side-mode đều tính)
  — điểm khác biệt rõ với I49 (chỉ áp dụng campaign).

DoD chung: `../README.md`.
