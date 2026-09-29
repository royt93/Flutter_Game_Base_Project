---
id: FEAT-96
title: "Reward plan dry-run preview"
type: feature
priority: P0
effort: M
source: "differentiator độc quyền"
---

## Vị trí

Mới, tích hợp `lib/core/reward_transaction_pipeline.dart`, `lib/core/economy_wallet.dart` (`earn`/`trySpend` dòng 97-109), `lib/core/inventory_service.dart` (`grant`/`consume`, capacity dòng 110-149), `lib/core/utils/sdk_result.dart`.

## Hiện trạng

`RewardTransactionPipeline.grant` (reward_transaction_pipeline.dart:242) chỉ execute trực tiếp — không có API cho consumer render "nhận gì" (currency + inventory item) trước khi mutate state thật, và không biết trước capacity/balance sẽ đủ hay tràn.

## Vì sao cần / Hậu quả

UI reward chọn-1-trong-N hoặc reward lớn (level up, event) cần hiển thị preview chính xác trước khi user confirm — tránh vừa mutate vừa rollback khi capacity đầy.

## Đề xuất

API preview immutable hợp nhất nhiều reward lines (currency qua wallet, item qua inventory) + kiểm tra capacity/balance mà KHÔNG ghi storage. `execute(plan)` dùng lại đúng plan/idempotency key đã preview; từ chối nếu plan stale (state đổi từ lúc preview) hoặc malformed. Một transaction ID cho cả preview+execute.

## Acceptance criteria

- [x] Preview không ghi storage (verify bằng spy/no write call).
- [x] Preview deterministic với cùng state đầu vào.
- [x] Execute từ chối plan stale (state thay đổi giữa preview và execute) hoặc plan đã đổi nội dung.
- [x] Malformed plan (currency rỗng, amount <=0, item vượt capacity) bị validation reject trước khi mutate.
- [x] Unit test bao mọi nhánh trên.

## Quyết định

Kiến trúc (chốt qua `AskUserQuestion`): mở rộng `RewardTransactionPipeline` hiện có thay vì tạo service riêng — tái dùng `_guard`,
idempotency ledger, và state machine `pending→partial→committed` đã có sẵn (BUG-71/BUG-88), KHÔNG dùng compensating rollback cho
partial-failure (currency commit xong, item fail) mà hợp nhất cả 2 loại line vào cùng 1 record, retryable qua `resumePending()` đã có.

API mới hoàn toàn additive (constructor `.withInventory`, method `grantWithItems`, `RewardTransactionRecord.withItems`) — không đổi
signature `grant()`/constructor mặc định, `tool/api_compatibility.dart check` báo `additive`.

- `InventoryService.previewGrant()`: tách `_computeGrant()` thuần từ `grant()` làm helper dùng chung, không mutate `_slots`.
- `RewardTransactionPipeline.preview()`: validate input, tính overflow currency CỘNG DỒN theo từng currency (không chỉ từng dòng riêng lẻ — đây là 1 trong 2 gap audit tìm ra, đã fix), gọi `inventory.previewGrant()` nếu có itemLines, trả `RewardPlan` bất biến với `stateFingerprint` (snapshot balance+inventory) và `contentFingerprint` (transactionId+lines+receiptMeta, deep-copy JSON round-trip để chống alias mutation — gap thứ 2 audit tìm ra, đã fix).
- `executePlan(plan)`: recompute cả 2 fingerprint, reject `SdkFailure(kind: conflict)` nếu lệch (state đổi HOẶC nội dung plan bị tamper), rồi mới delegate `grantWithItems(...)`.

TDD: viết test trước (đỏ) cho từng case trong acceptance criteria + 2 case audit bổ sung (tích luỹ overflow nhiều dòng cùng currency,
deep-copy receiptMeta chống mutate-sau-preview), implement tới khi xanh.

Test coverage: unit (`test/core/reward_transaction_pipeline_test.dart` nhóm `FEAT-96: reward plan preview/execute` — preview không ghi storage, preview deterministic, executePlan reject stale, malformed plan reject tại preview, executePlan thành công combined currency+item, item fail sau currency commit rồi resume thành công, itemLines không có inventory bị reject, backward-compat fromJson record cũ; `test/core/inventory_service_test.dart` nhóm `FEAT-96: previewGrant` — 6 case), widget (`example/test/widget_showcase_screen_test.dart`: happy-path claim qua UI thật, cancel dialog không claim, stale-plan-conflict qua live pipeline instance), integration/device (`example/integration_test/app_boot_test.dart`: preview+executePlan bằng wallet/inventory/pipeline thật, xác nhận balance/inventory đúng sau khi dựng instance mới mô phỏng restart, chạy trên thiết bị Android thật TECNO KJ7).

Kết quả: `flutter analyze` sạch root + `example/`. `flutter test --exclude-tags slow` sạch root (1 flake tiền-tồn-tại không liên quan ở
`energy_service_test.dart`, xác nhận qua `git stash` + chạy lại độc lập, không phải regression từ batch này) + sạch `example/`
(195 tests pass). Smoke test device thật pass.

Tự chấm ban đầu 9/10 sau audit fork độc lập tìm 2 gap thật: (1) overflow check không cộng dồn nhiều dòng cùng currency,
(2) `receiptMeta` bị alias tham chiếu nên mutate map gốc sau `preview()` âm thầm đổi nội dung plan mà fingerprint không phát hiện.
Cả 2 đã fix + có regression test riêng. Rescore từ CÙNG audit fork sau fix: **9.5/10** — "Both fixes verified, tests pass, no
regressions found... Ship it." (0.5 còn lại: content-fingerprint check là defense-in-depth cho 1 đường đã không thể chạm tới qua
public API, không phải deduction thật).

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

Cao. Đã verify `grant` (reward_transaction_pipeline.dart:242-317) execute-only, `InventoryService` constructor (106-149) có `capacity`/atomic multi-line semantics đã document, `EconomyWallet.earn`/`trySpend` (97-109) là 2 entrypoint mutate chính không có preview.
