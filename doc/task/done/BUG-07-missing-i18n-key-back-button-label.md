---
id: BUG-07
title: "Key i18n 'back_button_label' được dùng nhưng không tồn tại trong AppTranslations"
type: bug
priority: P1
effort: S
verified: true
source: Claude tự phát hiện khi verify, đọc code thật
---

## Vị trí
- Dùng ở: `lib/presentation/widgets/neon_icon.dart:47` (`semanticLabel: 'back_button_label'.tr`)
- Thiếu ở: `lib/core/app_translations.dart` (chỉ có 7 key: `app_name`, `settings`,
  `language`, `sound`, `ok`, `cancel`, `widget_showcase` — không có `back_button_label`)

## Vấn đề
GetX `.tr` khi không tìm thấy key sẽ trả về CHÍNH literal key đó làm fallback.
Nghĩa là nút back hiện tại có `semanticLabel` là chuỗi thô `"back_button_label"`
thay vì "Back"/"Quay lại" — screen reader đọc ra rác kỹ thuật cho người dùng
khiếm thị.

## Đề xuất fix
Thêm key `back_button_label` vào cả 2 map `en` (`'Back'`) và `vi` (`'Quay lại'`)
trong `AppTranslations`.

## Acceptance criteria
- [x] Key tồn tại ở cả `en` và `vi`.
- [x] Test key-parity (nếu làm ENH-01) bắt được lỗi này nếu tái diễn.

## Quyết định

Đã fix đúng như đề xuất từ trước — xác nhận lại qua đọc code thật (audit tổng hợp cuối phiên): `back_button_label` tồn tại ở cả `en` (`'Back'`, `app_translations.dart:27`) và `vi` (`'Quay lại'`, dòng 40). `test/core/app_translations_test.dart:11-14` có test key-parity `'back_button_label tồn tại ở cả en và vi'` bắt đúng case này nếu tái diễn.

File này được đóng qua 1 đợt batch-move cũ (`chore: move 11 completed bug tasks from todo to done`) trước khi quy ước "Quyết định" + tick checkbox trở thành bắt buộc trong phiên này — chỉ là thiếu sót hồ sơ, không phải bug chức năng còn tồn tại. Bổ sung lại cho đúng chuẩn, không cần sửa code.

