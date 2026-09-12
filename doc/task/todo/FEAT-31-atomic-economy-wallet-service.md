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
- [ ] Hai spend cạnh tranh không làm balance âm; cùng transaction id chỉ áp dụng một lần qua restart.
- [ ] Corrupt/migrated save có recovery policy không tăng balance.
- [ ] UI demo animate balance theo `NeonTheme` và tôn trọng reduced motion.
- [ ] Unit, widget, integration và device smoke test bao phủ earn/spend/insufficient funds/idempotency/race/persist/corrupt.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Chốt quan hệ với IDEA-33 rồi implement từng slice bằng TDD. Kết thúc mỗi vòng phải audit changes, chấm /10, bổ sung unit + widget + integration test cho mọi case, analyze/test root + example và smoke Android device thật có bằng chứng. Lặp đến >9/10; chỉ lúc đó commit + push. Sau push cập nhật Quyết định, chuyển task sang done, commit + push lần hai.

