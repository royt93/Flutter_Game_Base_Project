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
- [x] Test race: `drain()` đang xử lý item cũ, `enqueue()` cùng key được gọi giữa chừng — sau khi drain xong, item MỚI vẫn còn trong outbox (không bị xóa nhầm).
- [x] Test eviction: item ưu tiên cao hơn không bị evict bởi item ưu tiên thấp hơn; item `manualReview == true` không bao giờ bị evict tự động.
- [x] Test merge: `merger` ném exception không làm hỏng state outbox — item vẫn còn đó, có thể retry lại.
- [x] Không đổi hành vi `drain`/`enqueue` trong trường hợp không có race/không evict/không lỗi merge.

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

## Quyết định

Fix cả 3 bug đúng như đề xuất:

1. **Race enqueue/drain**: `_remove(String idempotencyKey)` đổi thành `_remove(OutboxItem item)`, xóa theo `identical(i, item)` thay vì so khớp key. `OutboxItem` không override `==`/`hashCode` nên đây thực chất chỉ làm TƯỜNG MINH thứ `drain()`'s `items.contains(item)` (dòng ngay phía trên) đã ngầm dựa vào từ trước — nhất quán, không phát minh cơ chế mới.
2. **Eviction sai**: thêm điều kiện lọc ứng viên evict — loại `manualReview == true` VÀ chỉ giữ `priority < priority-của-item-mới`. Nếu không còn ứng viên nào, `enqueue` trả `SdkFailure` (kind `validation`) thay vì âm thầm evict nhầm hoặc âm thầm không làm gì — nhất quán với triết lý "không silent-fail" của `SdkResult` xuyên suốt codebase này.
3. **Merger throw phá state**: bọc `merger!(...)` bằng `try/catch`, log qua `CrashReporter.maybe?.recordError(...)` (đúng convention đã dùng ở `privacy_aware_analytics_sampler.dart`/`sdk_event_schema_registry.dart`), item giữ nguyên trong queue để lần `drain()` sau retry — coi như 1 lần attempt thất bại, giống hệt cách nhánh `SdkFailure<SyncOutcome>` của `_attempt` đã xử lý transient failure.

**TDD:** viết 6 test mới trước — `git stash` riêng file lib, chạy lại — 4/6 fail đúng thật (test race: outbox rỗng thay vì có 1 item; 2 test eviction-reject: trả `SdkSuccess` thay vì `SdkFailure`; test merger-throw: exception `Bad state: merger bug giả lập` thoát THẲNG ra ngoài `drain()`, đúng y hệt mô tả bug — không phải giả định). 2 test còn lại (evict đúng khi có ứng viên hợp lệ; happy-path không đổi) pass cả code cũ/mới — hợp lý, dùng để chứng minh KHÔNG phá hành vi bình thường. Khôi phục fix: cả 28 test (22 cũ + 6 mới) pass.

**Không phá gì:** `flutter analyze` root sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: 2056 pass / 19 fail (đúng 19 golden có sẵn; 1 lần chạy trước đó ra 20 fail nhưng verify lại bằng cách chạy riêng `test/widget/goldens/` xác nhận đúng 19 — lần 20 là flaky-dưới-tải đã biết trước đó trong repo, không liên quan tới thay đổi này, rerun lại ra đúng 19).

Không cần smoke test device — fix nội bộ tầng service thuần (concurrency/eviction/error-handling), không có UI thật trong `example/` gọi các API này theo cách lộ ra 3 bug này.

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 3 bug độc lập trong cùng file, TDD xác nhận rõ ràng bằng lỗi/exception thật (không phải suy đoán), giữ nguyên hành vi bình thường (2 test xác nhận không đổi). Trừ 0.5 vì đây là 3 bug gộp trong 1 task effort M, rủi ro hồi quy tổng thể cao hơn 1 fix đơn lẻ dù mỗi phần đã test riêng.
