# T1 — Fix settings_screen locale-change test

**Epic:** Test Coverage (liên quan E4-S9 trong `../../backlog.md`) · **SP:** 3 · **Pri:** P2 · **Deps:** none

## Mục tiêu
Sửa/viết lại test đổi locale trong `settings_screen` đang là nợ kỹ thuật đã biết (ghi chú trong `doc/feat.md`), đảm bảo widget re-render đúng bản dịch mới khi đổi locale, không lộ raw translation key.

## Vì sao
`AppTranslations` bắt buộc mọi ngôn ngữ có đủ key (`app_translations_test.dart` đã guard phần data), nhưng thiếu guard ở tầng widget: đổi locale trong `settings_screen` có re-render đúng UI hay không chưa được test tự động xác nhận, dễ regress âm thầm khi thêm locale mới hoặc đổi cách bind `Obx`/`GetX` cho text.

## Acceptance criteria
- [ ] Test dựng `SettingsScreen` trong `GetMaterialApp`, đổi locale qua service (`LocaleService`), verify text hiển thị đổi theo bản dịch mới (không còn raw key dạng `settings.title`)
- [ ] Test cover ít nhất 2 locale khác nhau (ví dụ `en` và 1 locale không phải Latin, vd `ja` hoặc `vi`) để bắt lỗi thiếu key
- [ ] Test nằm trong suite không gắn tag `slow`, chạy được qua `flutter test --exclude-tags slow`
- [ ] `flutter analyze` 0 lỗi

## Subtasks (gợi ý file)
- `test/widget/settings_screen_test.dart` (tạo mới nếu chưa có, hoặc bổ sung file test hiện tại) — pump `SettingsScreen`, gọi đổi locale, `tester.pump()`, assert text.
- Đọc `lib/core/app_translations.dart` + chỗ `LocaleService` đổi locale (`Get.updateLocale`) trước khi viết test, để biết đúng API kích hoạt đổi ngôn ngữ trong widget test.

## Ghi chú kỹ thuật
Đây là task test-only, không sửa code sản phẩm trừ khi test lộ ra bug thật (ví dụ text không rebuild vì thiếu `Obx`/`GetX` wrap) — nếu phát hiện bug thật khi viết test, ghi rõ trong PR và sửa kèm.

DoD chung: ../README.md.
