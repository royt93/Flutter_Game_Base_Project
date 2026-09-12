---
id: FEAT-36
title: "PersistentCooldownService — cooldown keyed, reactive và sống qua restart"
type: feature
layer: core
priority: P1
effort: M
depends_on: [FEAT-32]
related_to: [IDEA-40]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn quản lý cooldown reward/booster/action bằng một SSOT chống chỉnh giờ.

## Sprint slices
- Model cooldown keyed: start/end/status/remaining và policy restart/cancel.
- Repository versioned persistence; service GetX reactive không tạo timer mỗi key.
- Batch tick scheduler, foreground refresh và cleanup expired entries.
- `CountdownChip` adapter/demo dùng state từ service.

## Acceptance criteria
- [ ] Start/read/cancel/restart policy đúng qua app restart và clock anomaly.
- [ ] N cooldown không tạo N timer; subscriber nhận state immutable.
- [ ] Key/input/corrupt save được validate và không mở khóa sớm.
- [ ] Widget countdown hiển thị cùng remaining với service.

## Prompt loop feature
Đọc task/dependencies; implement model → repository → service → widget adapter bằng TDD. End loop: audit và chấm /10; unit test + widget test + integration test mọi case time/persist/corrupt/lifecycle; analyze/test root + example; smoke Android device thật có kill/relaunch proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
