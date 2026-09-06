---
id: FEAT-24
title: safe_json — defensive parsers (asIntOr/asStringOr/asDoubleOr...) cho save/cloud data
type: feature
priority: P1
effort: S
source: user pick (chốt trong phiên chọn util mới)
---

## Vì sao cần
FEAT-05 (save-slot versioning) và FEAT-16 (cloud save) đều sẽ đọc dữ liệu
JSON từ nguồn không hoàn toàn tin cậy (file cũ bị lỗi, cloud data từ version
app khác, người dùng sửa tay). Parse trực tiếp (`json['x'] as int`) sẽ crash
toàn bộ quá trình load chỉ vì 1 field sai kiểu/thiếu.

## Đề xuất phạm vi
Bộ hàm thuần trong `lib/core/utils/safe_json.dart`:
```dart
int asIntOr(Object? v, int fallback);
String asStringOr(Object? v, String fallback);
double asDoubleOr(Object? v, double fallback);
bool asBoolOr(Object? v, bool fallback);
```
Không throw bao giờ — luôn trả `fallback` nếu kiểu không khớp/`null`.

## Yêu cầu test
- **Unit test**: mỗi hàm test đủ case: đúng kiểu, sai kiểu, `null`, kiểu số
  nguyên đọc từ JSON dạng `double` (JSON không phân biệt int/double khi decode
  qua `dart:convert` — case thực tế hay gặp), string rỗng.

## Demo
Không cần demo UI (thuần logic) — dùng làm nền cho FEAT-05/FEAT-16 khi triển khai.

## Acceptance criteria
- [ ] Không hàm nào throw với bất kỳ input `Object?` nào (kể cả `List`, `Map` truyền nhầm chỗ).
- [ ] Test phủ đủ case JSON số thực tế (int decode ra double).
