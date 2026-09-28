---
id: BUG-86
title: "kit_bootstrap để lại module audio nửa đăng ký khi init throw"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/kit_bootstrap.dart:130` nhánh audio.

## Hiện trạng

`Get.put(audio)` (dòng 131) chạy TRƯỚC `await audio.init()` (dòng 137). `init` throw → instance nửa hỏng nằm lại trong registry; lần `initialize` sau skip vì `isRegistered` đã true → audio chết vĩnh viễn tới khi restart process.

## Vì sao cần / Hậu quả

Lỗi audio transient (thiết bị không có audio backend) biến thành mất tiếng vĩnh viễn cho cả session.

## Đề xuất

`init` TRƯỚC rồi mới `Get.put` (mẫu an toàn nhất), hoặc unregister trong catch khi init fail. Áp dụng tương tự nhánh `wakeLock` (dòng 167-175, cùng pattern put-trước-init-sau).

## Acceptance criteria

- [x] Test init-throw → không còn registration nửa hỏng; gọi lại `initialize` thành công.
- [x] `errors` trong `RoyCasualKitResult` vẫn ghi nhận module lỗi lần đầu.

## Quyết định

**Implementation:** Đảo thứ tự ở CẢ 2 nhánh `audio` và `wakeLock` (task đã
ghi chú `wakeLock` cùng pattern lỗi, không phải pattern an toàn) —
`await instance.init()` chạy TRƯỚC `Get.put(instance, ...)`. Nếu `init()`
throw, không có gì được đăng ký vào Get và `_owned` không có closure dọn
dẹp nào được thêm → exception thoát ra ngoài, bị bắt bởi outer
try/catch của `_initialize`, ghi vào `errors[module]`, KHÔNG để lại instance
nửa đăng ký. Lần `initialize()` sau `Get.isRegistered<X>()` vẫn `false` nên
retry chạy lại đầy đủ từ đầu (không bị skip vĩnh viễn).

**TDD:** 2 test mới trong `test/core/kit_bootstrap_test.dart` (group
`BUG-86`) — request module `audio`/`wakeLock` riêng lẻ KHÔNG kèm `storage`
→ `init()` throw THẬT (do `StorageService.to` bên trong `init()` chưa đăng
ký, không cần mock giả lập) → verify `Get.isRegistered` là `false` và
`errors` có ghi nhận; gọi lại `initialize` với cấu hình đúng (có storage)
→ đăng ký + `init()` chạy thành công thật sự (verify qua giá trị
`muted`/`enabled` phản ánh đúng state đã persist trước đó).

**Kết quả:** `flutter analyze` sạch root + `example/`. `flutter test
--exclude-tags slow` sạch root + `example/`, không regression trên 15 test
khác trong `kit_bootstrap_test.dart`.

**Tự chấm:** 9/10. Fix tối thiểu (đảo 2 dòng mỗi nhánh), tận dụng throw THẬT
sẵn có trong code (thiếu storage) thay vì phải viết mock riêng để giả lập
init-throw — test do đó verify đúng hành vi thật của hệ thống.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify thứ tự put-dòng-131 trước init-dòng-137, và nhánh wakeLock cùng pattern.
