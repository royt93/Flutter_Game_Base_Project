---
id: BUG-116
title: "EconomyWallet.earn/trySpend nhận số âm: earn(-30) trừ tiền, trySpend(-500) cộng tiền"
type: bug
layer: lib/core/economy_wallet
priority: P1
effort: S
source: "Scan SDK 2026-11-13 (fork); tự tái hiện độc lập trước khi sửa"
---

## Tái hiện (đã chạy, test tạm đã xoá)
Ví có 100 `coin`: `earn(amount: -30)` trả thành công, số dư 70; `trySpend(amount: -500)` trả thành công, số dư 570 (cộng 500 qua API chi tiêu). Chỉ `delta == 0` bị chặn trong `_apply`. Inventory, progression và ledger đều đã chặn `amount <= 0`; ví là chỗ duy nhất sót. `RewardTransactionPipeline` đã chặn từ trước nên không bị ảnh hưởng.

## Đã sửa
`earn` và `trySpend` trả `SdkFailure(validation)` cho `amount <= 0`, trước khi vào `_apply` (nên không đốt `transactionId`). Test `BUG-116` trong `economy_wallet_test.dart` (đỏ khi bỏ sửa, xanh khi có); `test/core` 2038 test, 442 test example, API gate vẫn xanh. CHANGELOG ghi mục Behavior change. Các caller trong `example/lib` chỉ truyền số dương.
