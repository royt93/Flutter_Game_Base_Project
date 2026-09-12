---
id: FEAT-44
title: "InventoryService — item stack, capacity và grant/consume nguyên tử"
type: feature
layer: game/data-logic
priority: P1
effort: L
depends_on: [FEAT-34, FEAT-37, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn inventory generic cho consumable/equipment mà không viết persistence và invariant lại từ đầu.

## Sprint slices
- Item definition/id, stack rule, rarity metadata và inventory snapshot immutable.
- Repository versioned + service grant/consume/move/equip theo command.
- Capacity/stack overflow policy; idempotency qua transaction id.
- Query/selectors reactive cho UI, không đưa Widget vào data layer.

## Acceptance criteria
- [ ] Grant/consume không âm, không vượt stack/capacity và atomic khi nhiều item.
- [ ] Unknown/stale item id và corrupt save có recovery không cấp thêm item.
- [ ] Concurrent operations và duplicate transaction deterministic.
- [ ] Persist/reload/migration giữ slot, stack và equipped state.

## Prompt loop feature
Đọc task/dependencies; rã vertical slices và TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi item/stack/capacity/race/corrupt case; analyze/test root + example; smoke device thật qua inventory demo. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

