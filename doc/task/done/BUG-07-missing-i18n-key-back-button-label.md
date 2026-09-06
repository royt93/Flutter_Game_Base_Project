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
- [ ] Key tồn tại ở cả `en` và `vi`.
- [ ] Test key-parity (nếu làm ENH-01) bắt được lỗi này nếu tái diễn.
