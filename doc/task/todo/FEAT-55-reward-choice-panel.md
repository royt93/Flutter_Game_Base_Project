---
id: FEAT-55
title: "RewardChoicePanel — chọn reward có trạng thái selected/locked/claimed"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-42, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn chọn một reward trong nhiều lựa chọn với xác nhận rõ và không claim hai lần.

## Sprint slices
- Immutable option model và panel single/multi select configurable.
- Animated selection, locked reason, confirm loading/success/error.
- Command trả option ids; grant nằm trong RewardTransactionPipeline.

## Acceptance criteria
- [ ] Disabled/locked không select; selection và confirm obey min/max.
- [ ] Rapid confirm/rebuild/error retry không double claim.
- [ ] Empty/duplicate id/too many options có policy rõ.
- [ ] Keyboard/semantics/text scale/RTL và reduced motion đầy đủ.

## Prompt loop feature
Đọc task/reward pipeline; TDD state and UI. End loop: audit, chấm /10; unit test + widget test + integration test mọi select/lock/confirm/error/duplicate; analyze/test root + example; smoke Android device thật chứng minh claim idempotent. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

