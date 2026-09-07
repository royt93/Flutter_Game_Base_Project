---
id: BUG-14
title: "4 chỗ gọi dlog() tự thêm 'roy93~' thủ công, bị nhân đôi tiền tố"
type: bug
priority: P3
effort: S
source: Claude, audit round 3 (fork agent)
---

## Vị trí
- `lib/core/reminder_service.dart:59` — `dlog('roy93~ ReminderService.scheduleNext failed: $e');`
- `lib/core/reminder_service.dart:68` — `dlog('roy93~ ReminderService.cancel failed: $e');`
- `lib/core/storage_service.dart:277` — `dlog('roy93~ importAll rollback thất bại: $rollbackError');`
- `example/lib/main.dart:112` — `dlog('roy93~ SharedPreferences init failed, dùng in-memory fallback: $e');`

## Hiện trạng
`lib/core/debug_log.dart` — `dlog()` đã tự động thêm tiền tố:
```dart
void dlog(String msg) {
  if (kDebugMode) debugPrint('roy93~ $msg');
}
```
4 call site trên lại tự gõ thêm `'roy93~ '` ở đầu message truyền vào, tạo ra
log thật là `roy93~ roy93~ ...` (đã tận mắt thấy pattern này lặp lại nhiều
lần trong live log trên thiết bị thật khi verify các round trước, ví dụ
`roy93~ roy93~ AuroraBgLayer: load shader thất bại...` — lúc đó không để ý
ra đây là bug, chỉ tưởng là format log bình thường).

## Hậu quả
Không ảnh hưởng chức năng (logcat filter theo `roy93~` vẫn khớp bình
thường), nhưng làm log khó đọc hơn và là dấu hiệu code không nhất quán với
đúng convention `dlog()` đã định nghĩa (CLAUDE.md: "All debug prints are
prefixed `roy93~` for easy logcat filtering" — ý là tự động, không phải
caller tự gõ).

## Đề xuất fix
Bỏ `'roy93~ '` thủ công ở cả 4 chỗ, để `dlog()` tự lo phần tiền tố.

## Acceptance criteria
- [x] Cả 4 call site không còn chuỗi `roy93~` thủ công trong message truyền cho `dlog()`.
- [x] `grep -rn "dlog('roy93~\|dlog(\"roy93~" lib/ example/lib/` không còn kết quả.

## Quyết định
Sửa cả 4 chỗ audit tìm ra, và tìm thêm được 1 chỗ thứ 5 audit bỏ sót do
grep single-line không khớp: `lib/presentation/widgets/shader_ticker_layer.dart`
gọi `dlog(\n  'roy93~ ...'\n)` — chuỗi trải nhiều dòng nên pattern grep gốc
không bắt được. Xác nhận sạch bằng `grep -rzoP "dlog\(\s*['\"]roy93~"` (đa
dòng) sau khi sửa — không còn kết quả nào. Verify: `flutter analyze` +
`flutter test --exclude-tags slow` sạch ở root (428 pass) và `example/` (29
pass); `integration_test/app_boot_test.dart` chạy trên Samsung S24 Ultra
thật (`R5CX613VZBR`) khớp baseline đã biết (4 pass + 4 skip, 0 fail); boot
log live trên máy xác nhận mỗi dòng chỉ còn đúng 1 `roy93~`.
