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

- [ ] Preview không ghi storage (verify bằng spy/no write call).
- [ ] Preview deterministic với cùng state đầu vào.
- [ ] Execute từ chối plan stale (state thay đổi giữa preview và execute) hoặc plan đã đổi nội dung.
- [ ] Malformed plan (currency rỗng, amount <=0, item vượt capacity) bị validation reject trước khi mutate.
- [ ] Unit test bao mọi nhánh trên.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

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
