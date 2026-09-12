---
id: FEAT-31
title: "Atomic EconomyWallet — nguồn dữ liệu thật cho CurrencyCounter và giao dịch reward"
type: feature
priority: P2
effort: L
source: Codex + independent AI synthesis
depends_on: [BUG-35, ENH-56]
---

## User story
Là game developer, tôi muốn earn/spend currency nguyên tử, idempotent và persist được để không tự viết lại logic chống double-tap/double-reward cho mỗi game.

## MVP slices
1. Domain model immutable: currency id, balance, transaction id/type/time.
2. Repository/service SSOT trên `VersionedJsonStore`, không để widget ghi storage.
3. `earn`, `trySpend`, `balanceOf`; reject âm/overflow và transaction id trùng.
4. Adapter state để `CurrencyCounter` render reactive; example demo earn/spend.

## Ngoài scope MVP
IAP receipt validation, exchange rate, server authority và full accounting ledger. Phối hợp với IDEA-33 để không tạo hai ledger cạnh tranh.

## Acceptance criteria
- [x] Hai spend cạnh tranh không làm balance âm; cùng transaction id chỉ áp dụng một lần qua restart.
- [x] Corrupt/migrated save có recovery policy không tăng balance.
- [x] UI demo animate balance theo `NeonTheme` và tôn trọng reduced motion.
- [x] Unit, widget, integration và device smoke test bao phủ earn/spend/insufficient funds/idempotency/race/persist/corrupt.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Chốt quan hệ với IDEA-33 rồi implement từng slice bằng TDD. Kết thúc mỗi vòng phải audit changes, chấm /10, bổ sung unit + widget + integration test cho mọi case, analyze/test root + example và smoke Android device thật có bằng chứng. Lặp đến >9/10; chỉ lúc đó commit + push. Sau push cập nhật Quyết định, chuyển task sang done, commit + push lần hai.

## Implementation evidence

- Added reactive `EconomyWallet` SSOT with atomic keyed earn/spend operations, non-negative/overflow validation and transaction idempotency.
- Persisted wallet snapshot through `StorageService`; corrupt payloads recover to an empty safe balance and never grant currency.
- Added unit, widget and consumer integration coverage for earn, spend, insufficient funds, concurrent race, duplicate transaction, corrupt data and restart persistence.
- `CurrencyCounter` renders wallet state with its existing animated/reduced-motion behavior.
- Root analyze/full suite passed: **663 tests**. Example analyze/full suite passed: **30 tests**.
- Android smoke passed on physical Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36); evidence: `doc/task/evidence/FEAT-31-device-smoke.log`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
