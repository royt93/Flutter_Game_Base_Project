---
id: ENH-10
title: AppTranslations chưa có pattern số nhiều/ICU (plural)
type: enhance
priority: P2
effort: S
verified: true
source: Claude, phát hiện khi audit bổ sung
---

## Vấn đề
`AppTranslations` hiện chỉ là `Map<String, String>` phẳng — không có cơ chế
số nhiều kiểu ICU (`{count, plural, one{...} other{...}}`) mà gói `intl` hỗ
trợ sẵn. Khi FEAT-07 (Daily Login Calendar) hay bất kỳ text dạng "còn X
ngày"/"còn X lượt" ra đời, sẽ phải tự ghép chuỗi thủ công, dễ sai ngữ pháp số
nhiều ở locale khác `vi`/`en` (tiếng Việt không chia số nhiều nhưng `en` có).

## Đề xuất
Không cần làm ngay (chưa có text nào cần plural hiện tại) — ghi nhận trước
làm nợ kỹ thuật, và khi thêm FEAT-07/tương tự, dùng `Intl.plural(...)` của
gói `intl` (đã là dependency sẵn có, không cần thêm gói mới) thay vì tự ghép
chuỗi.

## Acceptance criteria
- [ ] (Khi cần) text số nhiều đầu tiên trong app dùng `Intl.plural`, không string-concat thủ công.
