# X7 — Fix chuỗi hardcode bỏ qua `.tr` (comeback/daily/leaderboard)

**Epic:** i18n/polish · **SP:** 2 · **Pri:** Should · **Deps:** —

## Mục tiêu
Vài dialog/screen dựng thẳng chuỗi tiếng Việt/Anh literal thay vì key qua
`AppTranslations`, phá vỡ parity 22 locale (`AppTranslations.supported`).

Chỗ đã xác nhận qua source:
- `lib/presentation/screens/home_screen.dart:55,58,60` — dialog comeback
  bonus (`'Chào mừng trở lại!'`, `'Quà comeback: ...'`, `'Nhận'`).
- `lib/presentation/screens/home_screen.dart:71,74,77` — dialog daily reward
  (`'Daily reward — Day $nextStreak'`, `'Nhận $preview xu hôm nay!'`, `'Nhận'`).
- `lib/presentation/screens/leaderboard_screen.dart:24` — title AppBar
  (`'Leaderboard'`).
- `lib/presentation/screens/leaderboard_screen.dart:84` — `'You'` (tên người
  chơi trong bảng xếp hạng).

## Vì sao
CLAUDE.md: mọi text phải qua `AppTranslations`, test
`app_translations_test.dart` enforce đủ key mọi ngôn ngữ. 6 chỗ trên hiện
không đi qua `.tr` — người dùng ngôn ngữ khác tiếng Việt/Anh vẫn thấy
tiếng Việt/Anh cứng ở các màn này.

## Acceptance criteria
- [x] Thêm key mới vào `AppTranslations` (base English map + toàn bộ 22 map
      override) cho: comeback title/message/action, daily reward
      title(param streak)/message(param xu)/action, leaderboard title, "You".
- [x] 6 vị trí trên đổi sang gọi `.tr` (dùng `Get.parameters`/string
      interpolation sau khi `.tr` như các chỗ khác trong codebase đã làm cho
      chuỗi có tham số).
- [x] `app_translations_test.dart` vẫn xanh (đủ key mọi ngôn ngữ).
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh.

## Subtasks
1. `lib/core/app_translations.dart` — thêm key mới (English base + 22 locale
   override).
2. `lib/presentation/screens/home_screen.dart` — 6 chuỗi sang `.tr`.
3. `lib/presentation/screens/leaderboard_screen.dart` — 2 chuỗi sang `.tr`.

## Ghi chú kỹ thuật
Không đụng logic comeback/daily-streak — chỉ thay chuỗi hiển thị.

## Đã code (2026-07-13)
Key mới: `home_comeback_title`, `home_comeback_msg`, `home_daily_title`,
`home_daily_msg`, `home_weekend_banner`, `leaderboard_you` — thêm vào
`_extraEn`/`_extraVi` (base) + wave mới `_w29ByLang` (20 locale còn lại).
Nút "Nhận" ở cả 2 dialog dùng lại key `daily_claim` có sẵn (không tạo key
trùng). Message có tham số dùng `.trParams({'coin': ..., 'day': ...})`
(GetX extension có sẵn, chưa dùng chỗ nào khác trong repo trước đây).
Bonus: fix luôn weekend banner hardcode (`home_screen.dart` dòng ~112,
phát hiện khi đọc file, cùng loại vi phạm, cùng file) —
`leaderboard_title` đã có key sẵn từ trước, chỉ cần wire `.tr`.
`flutter analyze` 0 issues, `flutter test --exclude-tags slow` xanh (220+
test, bao gồm `app_translations_test.dart`).

DoD chung: `../README.md`.
