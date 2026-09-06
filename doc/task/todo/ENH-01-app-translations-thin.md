---
id: ENH-01
title: AppTranslations quá mỏng, không có test key-parity giữa en/vi
type: enhance
priority: P1
effort: M
source: cả 3 nguồn (agy/claude-CLI/fork) đều nêu
---

## Hiện trạng
`lib/core/app_translations.dart` chỉ có 2 locale (`en`/`vi`), 7 key. CLAUDE.md
tự thừa nhận "không có test enforcing key parity ở quy mô này". BUG-07 là ví
dụ thật của việc thiếu key mà không ai phát hiện cho tới khi grep thủ công.

## Đề xuất
1. Thêm test key-parity: so `keys['en'].keys.toSet()` với `keys['vi'].keys.toSet()`,
   fail nếu lệch — bắt được BUG-07 và mọi lệch key tương lai tự động.
2. Cân nhắc thêm 1 locale thứ 3 (chứng minh pattern "1 Map/locale" thực sự mở
   rộng được dễ dàng như CLAUDE.md mô tả).

## Acceptance criteria
- [x] Test key-parity tồn tại trong `test/core/`, fail khi cố tình xoá 1 key ở 1 locale.
- [x] CLAUDE.md cập nhật số locale/key nếu thêm locale mới.

## Quyết định
**Đã xong.** `test/core/app_translations_test.dart` đã có test key-parity
đúng như đề xuất (so `keys['en'].keys.toSet()` với `keys['vi'].keys.toSet()`)
từ trước, chỉ chưa được đóng task. CLAUDE.md cũng đã cập nhật lại đúng số
liệu hiện tại (10 key, không còn ghi "chưa có test key-parity"). Không thêm
locale thứ 3 (đề xuất tuỳ chọn trong task, không phải acceptance criteria).
