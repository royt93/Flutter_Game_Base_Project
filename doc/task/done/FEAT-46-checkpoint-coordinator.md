---
id: FEAT-46
title: "CheckpointCoordinator — autosave theo sự kiện và restore an toàn"
type: feature
layer: game/data
priority: P0
effort: M
depends_on: [FEAT-33, FEAT-34, FEAT-37]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn tiến trình quan trọng được checkpoint đúng lúc mà không gây write storm hoặc mixed state.

## Sprint slices
- Checkpoint participant registry + immutable aggregate snapshot.
- Debounce hot event, immediate critical save, serialized flush.
- Lifecycle flush timeout và dirty-state recovery marker.
- Restore validate toàn bộ trước apply; last-known-good fallback.

## Acceptance criteria
- [ ] N thay đổi nhanh coalesce đúng; critical checkpoint không bị debounce mất.
- [ ] Các participant được commit như một logical version, không mixed snapshot.
- [ ] Kill/error giữa save phục hồi last-known-good hoặc pending state rõ ràng.
- [ ] Background flush không deadlock và có diagnostic result.

## Prompt loop feature
Đọc task/storage/lifecycle dependencies; TDD crash points trước implementation. End loop: audit changes, chấm /10; unit test + widget test + integration test debounce/atomicity/failure/restart; analyze/test root + example; smoke Android device thật với background/force-stop/relaunch proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

