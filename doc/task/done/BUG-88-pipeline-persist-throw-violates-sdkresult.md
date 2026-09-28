---
id: BUG-88
title: "Reward pipeline persist throw phá hợp đồng SdkResult"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/reward_transaction_pipeline.dart:219` `_upsert`, gọi từ `grant` dòng 292, 303, 313.

## Hiện trạng

`_upsert` mutate `_records` rồi `await storage.setString` không catch. Persist throw thoát khỏi `grant`, dù public `grant` trả `Future<SdkResult<RewardTransactionRecord>>` và wallet failures đã map về `SdkFailure`.

## Vì sao cần / Hậu quả

Claim reward gặp storage lỗi sẽ unhandled exception; in-memory ledger còn mutate nhưng disk chưa sync.

## Đề xuất

Bọc các persist `_upsert` trong try/catch, trả `SdkFailure` kind storage; cân nhắc restore `_records` snapshot khi write fail để memory/disk đồng nhất.

## Acceptance criteria

- [x] Test persist-throw → `grant` trả `SdkFailure.storage`, không throw.
- [x] Test failure không báo `onGranted`/analytics và không để record committed giả trong memory.

## Quyết định

**Implementation:** Đổi private `_upsert` từ `Future<void>` sang
`Future<SdkFailure<RewardTransactionRecord>?>`. Trước mutation, snapshot
`_records`; sau mutation thử `storage.setString`; nếu persist throw →
rollback `_records` về snapshot rồi trả `SdkFailure(kind: storage,
cause: error, stackTrace: stack)` thay vì để exception thoát khỏi public
`grant`. Ba call site trong `grant` (persist `pending`, persist `partial`,
persist `committed`) đều kiểm tra failure và return ngay. `onGranted` +
analytics chỉ chạy SAU khi committed persist thành công — không phát tín
hiệu "đã grant" giả nếu disk chưa commit.

**TDD:** thêm `_ThrowingStorageService` (throw mọi setString hoặc đúng
lần gọi thứ N) + 2 test trong `test/core/reward_transaction_pipeline_test.dart`:
1. Throw ngay pending persist → `SdkFailure.storage`, auditTrail rỗng
   (rollback khỏi record vừa add), `onGranted` không phát.
2. Persist pending thành công, `wallet.earn` thành công, chỉ committed
   persist throw → `SdkFailure.storage`, `onGranted` không phát, auditTrail
   rollback về đúng record `pending` đã persist trước đó (không để
   `committed` giả chỉ tồn tại trong RAM).

**Kết quả:** `flutter analyze` sạch root + `example/`. Full file
`reward_transaction_pipeline_test.dart`: 23/23 pass; full root + example
suite sạch.

**Tự chấm:** 9.5/10. Fix không chỉ catch exception cho đủ hợp đồng
`SdkResult`, mà còn rollback memory về snapshot disk-consistent ở mọi
persist point — xử lý đúng cả nhánh pending, partial và committed.

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

Cao. Đã verify `_upsert` await storage write không catch (219-235), ba `grant` call site await trực tiếp (292, 303, 313).
