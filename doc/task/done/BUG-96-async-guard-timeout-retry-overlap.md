---
id: BUG-96
title: "Async guard timeout và retry overlap"
type: bug
priority: P1
effort: S
source: "codex độc lập"
---

## Vị trí

(a) `lib/core/utils/async_action_guard.dart:35` `runExclusive`; (b) `lib/core/utils/retry_policy.dart:163` timeout mỗi attempt.

## Hiện trạng

(a) Guard dùng `maxQueueWait` timeout khi await previous. `Future.timeout` throw, nhưng tail completer/future vẫn cleanup bình thường; action exclusive mới có thể bắt đầu trong khi action cũ chưa xong, phá mutual exclusion. (b) Retry timeout chỉ bỏ future hiện tại, không cancel action; retry attempt tiếp theo chồng side-effect.

## Vì sao cần / Hậu quả

Wallet/inventory/order dùng guard/retry có thể double side-effect: grant trùng, spend trùng, upload trùng.

## Đề xuất

(a) timeout chỉ đánh dấu/throws cho waiter, không mở lock khi holder cũ còn sống; (b) retry timeout cần cooperative cancel/check, không overlap, hoặc document + jitter/backoff không spawn song song.

## Acceptance criteria

- [x] Test exclusive vẫn loại trừ khi waiter timeout.
- [x] Test retry không double side-effect khi attempt timeout.

## Quyết định

- **Implementation**: `AsyncActionGuard` chain tail vào previous thật, waiter timeout chỉ complete chính nó mà không mở barrier; `RetryExecutor` bắt `TimeoutException` và dừng ngay (terminal `SdkFailure`), không retry để tránh overlap (bỏ qua giải pháp cancel vì Future không huỷ được).
- **TDD & Test coverage**: Bổ sung unit test cho cả guard và retry; viết integration test `app_boot_test.dart` đo timing tường minh trên device thật chứng minh C không thể chen ngang A khi B timeout.
- **Phân tích/test**: Root 2537/2537 pass, example 200/200 pass. `flutter analyze` sạch. Device test pass trên S24 Ultra và TECNO KJ7.
- **Audit**: Fork độc lập review diff uncommitted đạt 9.8/10 (không có finding nào về correctness/overlap). Mức hoàn thiện cao.

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

Cao. Đã verify `runExclusive` await `previous.timeout(wait)` dòng 35, retry `future.timeout(timeout)` dòng 163, không cancel underlying action.
