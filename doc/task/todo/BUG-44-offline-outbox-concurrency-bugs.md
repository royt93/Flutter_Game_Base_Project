---
id: BUG-44
title: "OfflineOutboxService: 3 bug concurrency/robustness (mất item mới khi race với drain, evict sai priority/manualReview, unhandled exception khi merge)"
type: bug
priority: P1
effort: M
source: "agy (độc lập) — 3 finding cùng file, gộp thành 1 task vì cùng root cause class (thiếu identity-check/exception-safety trong outbox lifecycle)"
---

## Vị trí
`lib/core/offline_outbox_service.dart` — `_remove()` (dòng ~345-346), eviction logic khi `capacity` đầy (~dòng 100-115 theo mô tả agy), merge/re-upload path khi có `conflictPolicy == merge`.

## Hiện trạng
1. **Race enqueue/drain mất item mới**: `drain()` đang `await uploader(...)` cho `item` key `K` (payload cũ). Cùng lúc, `enqueue(idempotencyKey: K, payload: newPayload)` cập nhật `items` với instance mới chứa `newPayload`. Khi upload cũ xong, `_remove(item.idempotencyKey)` dùng `items.removeWhere((i) => i.idempotencyKey == idempotencyKey)` — xóa NHẦM item mới (cùng key) thay vì chỉ xóa instance cũ đã upload xong.
2. **Eviction không xét priority/manualReview**: khi `capacity` đầy, item bị evict không được so sánh priority với item mới, và có thể evict cả item đang `manualReview == true` (đang chờ người dùng xử lý conflict thủ công).
3. **Merge conflict re-upload unhandled exception**: khi `conflictPolicy == ConflictPolicy.merge` và `merger` callback (do consumer cung cấp) ném exception trong lúc merge, exception không được bắt riêng, có thể làm hỏng state outbox giữa chừng.

## Vì sao cần / Hậu quả
(1) là mất dữ liệu thật: item mới nhất do người chơi vừa tạo (ví dụ 1 giao dịch offline mới) không bao giờ được sync lên server dù đã nằm trong outbox. (2) làm sai lệch dữ liệu ưu tiên cao bị evict trước dữ liệu ưu tiên thấp, và có thể mất item đang chờ người dùng tự xử lý xung đột. (3) có thể để lại outbox ở state không nhất quán khi merge lỗi.

## Đề xuất
1. `_remove` so sánh identity đối tượng chính xác (`items.removeWhere((i) => identical(i, item))`) thay vì chỉ so `idempotencyKey`.
2. Eviction: chỉ evict item có priority thấp hơn item mới, loại trừ hoàn toàn item có `manualReview == true` khỏi danh sách ứng viên evict.
3. Bọc merge callback bằng `try/catch` riêng, xử lý lỗi merge như 1 lần retry thất bại (không phá state), log qua `dlog`/`CrashReporter.maybe`.

## Acceptance criteria
- [ ] Test race: `drain()` đang xử lý item cũ, `enqueue()` cùng key được gọi giữa chừng — sau khi drain xong, item MỚI vẫn còn trong outbox (không bị xóa nhầm).
- [ ] Test eviction: item ưu tiên cao hơn không bị evict bởi item ưu tiên thấp hơn; item `manualReview == true` không bao giờ bị evict tự động.
- [ ] Test merge: `merger` ném exception không làm hỏng state outbox — item vẫn còn đó, có thể retry lại.
- [ ] Không đổi hành vi `drain`/`enqueue` trong trường hợp không có race/không evict/không lỗi merge.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-44-offline-outbox-concurrency-bugs.md` này trước khi làm. Đọc toàn bộ `lib/core/offline_outbox_service.dart` (đặc biệt `enqueue`/`drain`/`_remove`/eviction logic/`ConflictPolicy.merge` path) và test hiện có trước khi sửa. Implement bằng TDD — viết 3 test fail (1 cho mỗi bug) trước khi sửa code.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic thuần, service chưa có demo tương tác trong example).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — 1 nguồn (agy) nhưng mô tả kỹ thuật chi tiết, cụ thể (số dòng, đoạn code), phù hợp với cấu trúc thật của `OfflineOutboxService` (đã đọc code liên quan xác nhận class/method tồn tại đúng vị trí mô tả). Chưa tự viết test tái hiện race trước khi ghi task này (effort M, để lại cho vòng loop implement). Không trùng task nào trong `doc/task/done/`.
