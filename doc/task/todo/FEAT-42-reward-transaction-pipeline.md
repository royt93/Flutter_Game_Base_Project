---
id: FEAT-42
title: "RewardTransactionPipeline — reward idempotent xuyên suốt ad/IAP/quest/wallet"
type: feature
layer: game/logic
priority: P0
effort: L
depends_on: [FEAT-31, FEAT-34, FEAT-37, FEAT-38, IDEA-33]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn một transaction ID đi từ nguồn reward tới wallet/save/analytics để callback lặp không cấp thưởng hai lần.

## Sprint slices
- Model source, transaction id, reward lines, status và receipt metadata không chứa secret.
- Validate → reserve id → atomic grant → persist → emit event; resume transaction dang dở.
- Adapter cho rewarded ad, purchase seam, daily quest/login.
- Audit trail bounded và reconciliation API.

## Acceptance criteria
- [ ] Cùng transaction id chỉ grant một lần qua concurrent callback và restart.
- [ ] Partial failure có resume/rollback xác định, balance không lệch ledger.
- [ ] Invalid/corrupt/tampered reward bị từ chối trước mutation.
- [ ] Analytics failure không rollback reward đã commit.

## Prompt loop feature
Đọc task và dependencies; viết transaction state machine/threat cases trước TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi success/duplicate/race/crash-recovery/corrupt case; analyze/test root + example; smoke device thật chứng minh double callback không double grant. Chỉ khi work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.

