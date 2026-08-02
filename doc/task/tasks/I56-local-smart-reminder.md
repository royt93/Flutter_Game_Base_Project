# I56 — Local Smart Reminder

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Should
· **Deps:** I7 (Spin wheel), I48 (Login Streak), I50 (Weekly Goal Card)

## Mục tiêu

Thêm local notification (không backend) nhắc người chơi khi streak/spin
hàng ngày/weekly-goal sắp hết hạn — dùng `flutter_local_notifications`,
lên lịch lại mỗi lần mở app, tối đa 1 notification/ngày theo thứ tự ưu
tiên.

## Vì sao

Game đã có streak (I48)/spin (I7)/weekly-goal (I50) nhưng không chủ động
nhắc — người chơi dễ quên mở app trong ngày và rơi rụng dù hệ thống
retention đã tồn tại sẵn.

## Acceptance criteria

- [ ] Thêm dependency `flutter_local_notifications` vào `pubspec.yaml`
  (hiện chưa có bất kỳ package notification nào trong project).
- [ ] Tạo `lib/core/reminder_service.dart` — service mới, đăng ký
  permanent qua `Get.put(..., permanent: true)` trong `main.dart` `app()`
  (dòng ~25-70), theo đúng pattern `StorageService`/`AudioManager`.
- [ ] Hàm pure `Duration timeUntilNextDailyReset({required int nowEpochMs})`
  tính thời gian còn lại tới UTC midnight kế tiếp (dùng chung logic
  boundary với `_todayEpochDay()`, `game_controller.dart` dòng ~898-906)
  và `Duration timeUntilNextWeeklyReset({required int nowEpochMs})` dùng
  `weekIndexForEpochDay()` (`lib/data/weekly_goal.dart` dòng 8).
- [ ] Logic chọn loại nhắc theo thứ tự ưu tiên (chỉ bắn 1 loại/lần): (1)
  chưa `canClaimSpin` hôm nay + gần hết ngày → nhắc spin; (2) chưa điểm
  danh streak hôm nay → nhắc streak; (3) `weeklyGoalProgress` < target và
  còn ≤1 ngày trong tuần → nhắc weekly goal.
- [ ] Lên lịch lại mỗi lần app mở (`HomeScreenController`/`main.dart`) —
  huỷ lịch cũ trước khi đặt lịch mới, tránh tích luỹ notification trùng.
- [ ] Toggle bật/tắt trong `settings_screen.dart`, lưu
  `StorageKeys.remindersEnabled` (mặc định true) — tắt thì huỷ hết lịch
  đang chờ.
- [ ] Xin permission runtime đúng chuẩn Android 13+ (`POST_NOTIFICATIONS`)
  và iOS; permission bị từ chối → tắt tính năng âm thầm, không crash.
- [ ] Unit test `test/core/reminder_service_test.dart` cho phần pure
  logic (`timeUntilNextDailyReset`/`timeUntilNextWeeklyReset`) với các
  mốc biên trước/sau midnight UTC — không test phần gọi plugin thật.
- [ ] i18n nội dung notification (title/body theo từng loại nhắc), đủ 22
  locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Dependency notification đầu tiên trong project — cần thêm cấu hình
  Android (`AndroidManifest.xml` permission) và iOS (Info.plist) theo
  hướng dẫn chuẩn của package đã chọn.
- Tái dùng đúng logic epoch-day/epoch-week đã có ở `game_controller.dart`
  và `weekly_goal.dart` — không viết lại logic ngày/tuần riêng.
- `restartApp()` (`main.dart` dòng ~75-84) xoá hết singleton khi restore
  — `ReminderService` cần huỷ lịch cũ trong dispose/onClose để tránh
  notification treo sau khi data bị xoá.

DoD chung: `../README.md`.
