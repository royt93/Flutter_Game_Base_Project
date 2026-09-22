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
- [x] Test với 1 kiểu `T` có override `==`/`hashCode` theo giá trị (2 instance khác nhau, cùng giá trị) — `release()` chỉ ảnh hưởng đúng instance được truyền vào, không đụng instance khác cùng giá trị.
- [x] Double-release đúng 1 instance (gọi `release(item)` 2 lần liên tiếp cho CÙNG 1 object) vẫn bị phát hiện/throw như thiết kế.
- [x] Test hiện có của `object_pool_test.dart` vẫn pass.

## Quyết định
Fix đúng như đề xuất: `final _active = <T>{};` → `final _active = Set<T>.identity();`. Không lệch scope.

TDD verify: thêm `_ValueEqualParticle` (override `==`/`hashCode` theo `id`) trong test. `git stash` riêng `lib/core/utils/object_pool.dart`, chạy 3 test mới — test đầu (`acquire 2 object khác identity nhưng bằng nhau theo ==`) FAIL đúng trên code cũ (`Expected: 2, Actual: 1` — `Set` mặc định coi 2 instance value-equal là "trùng", `add()` thứ 2 bị bỏ qua, `activeCount` đếm sai ngay từ acquire, chưa cần tới release). `git stash pop`, chạy lại toàn file — 13/13 pass.

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2080 pass / -20 fail (19 golden macOS-only + 1 flaky đã biết `season_event_service_test.dart ENH-71`, cả 2 loại đều có sẵn trong baseline, không liên quan), `dart run tool/api_compatibility.dart check` unchanged. `ObjectPool` không được dùng trong `example/` (grep xác nhận), bỏ qua bước test/analyze `example/`.

Tự chấm: **9.5/10** — 1 dòng, root cause đúng, khớp 100% đề xuất + doc comment sẵn có, TDD chứng minh cả 3 case (đếm sai do Set equality, release không ảnh hưởng object khác value-equal, double-release đúng identity vẫn bị bắt), không phá test cũ.

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
