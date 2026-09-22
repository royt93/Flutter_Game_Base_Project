---
id: BUG-53
title: "ObjectPool._active dùng Set<T> mặc định (equality) thay vì Set<T>.identity(), phá vỡ kiểm tra double-release"
type: bug
priority: P1
effort: XS
source: "agy (độc lập), verify lại qua Read lib/core/utils/object_pool.dart:28-40,80-90"
---

## Vị trí
`lib/core/utils/object_pool.dart` — `_active` (dòng ~33), `release()` (dòng ~83).

## Hiện trạng
Doc comment cam kết kiểm tra IDENTITY (không phải equality) khi phát hiện double-release. Nhưng `final _active = <T>{};` tạo `LinkedHashSet<T>` mặc định — dùng `==`/`hashCode` của `T` để so sánh, không phải identity.

## Vì sao cần / Hậu quả
Nếu `T` (ví dụ 1 Flame `Component`, `Vector2`, hoặc bất kỳ object nào override `==`/`hashCode` theo giá trị) có 2 instance khác nhau nhưng cùng thuộc tính, `release()` (dùng `_active.remove(item)`) có thể XÓA NHẦM 1 object khác đang active thay vì đối tượng thật sự được release, hoặc bỏ lỡ phát hiện double-release thật — phá vỡ chính bất biến mà pool được thiết kế ra để bảo vệ (không double-release 1 component đang dùng).

## Đề xuất
Đổi khai báo thành `final Set<T> _active = Set<T>.identity();` — so sánh đúng theo con trỏ đối tượng, khớp với doc comment.

## Acceptance criteria
- [ ] Test với 1 kiểu `T` có override `==`/`hashCode` theo giá trị (2 instance khác nhau, cùng giá trị) — `release()` chỉ ảnh hưởng đúng instance được truyền vào, không đụng instance khác cùng giá trị.
- [ ] Double-release đúng 1 instance (gọi `release(item)` 2 lần liên tiếp cho CÙNG 1 object) vẫn bị phát hiện/throw như thiết kế.
- [ ] Test hiện có của `object_pool_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-53-object-pool-uses-equality-set-not-identity.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/object_pool.dart` và test hiện có trước khi sửa. Implement bằng TDD — viết test dùng 1 class test-only override `==`/`hashCode` để tái hiện đúng bug trước khi sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix 1 dòng, unit test đủ chứng minh — dù `ObjectPool` được dùng trong Flame component pooling, hành vi quan sát qua device không rõ ràng hơn unit test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, xác nhận `final _active = <T>{};` (không phải `Set<T>.identity()`), khớp chính xác mô tả của agy. Không trùng task nào trong `doc/task/done/`.
