---
id: FEAT-43
title: "PlayerProgressionService — XP, level curve và unlock reward"
type: feature
layer: game/data-logic
priority: P1
effort: M
depends_on: [FEAT-31, FEAT-37, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn cấu hình curve XP và nhận level-up event/reward ổn định qua restart.

## Sprint slices
- Immutable level definition/curve validator và progression state.
- Repository versioned persistence; service SSOT `grantXp` idempotent.
- Multi-level jump, max level, unlock reward qua pipeline.
- GetX reactive snapshot và example UI.

## Acceptance criteria
- [ ] Curve tăng hợp lệ; duplicate/missing/overflow config bị reject rõ.
- [ ] Grant XP qua nhiều level phát đúng từng unlock một lần.
- [ ] Concurrent grant, transaction trùng, max level và corrupt save không tăng quyền lợi sai.
- [ ] Restart giữ XP/level/unlock nhất quán.

## Prompt loop feature
Đọc task/dependencies; implement model→repository→service→UI bằng TDD. End loop: audit code, chấm /10; unit test + widget test + integration test mọi curve/grant/race/persist/corrupt case; analyze/test root + example; smoke Android device thật chứng minh multi-level flow. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

