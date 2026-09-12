---
id: FEAT-41
title: "GameSessionController — state machine chuẩn cho vòng đời ván chơi"
type: feature
layer: game/logic
priority: P0
effort: M
depends_on: [FEAT-32, FEAT-33, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn một SSOT cho `loading→ready→playing→paused→won/lost` để Flame và Flutter overlay không lệch state.

## Sprint slices
- Sealed session state + typed events và transition table pure Dart.
- GetX controller expose immutable snapshot/commands; reject transition bất hợp lệ.
- Bridge Flame pause/resume và SDK lifecycle với pause reason stack.
- Example demo win/loss/restart, không nhúng game-specific scoring.

## Acceptance criteria
- [x] Mọi state/event có transition hoặc typed rejection rõ; terminal state không tự thoát.
- [x] System pause và user pause lồng nhau không resume sớm.
- [x] Rapid/reentrant commands không phát event trùng.
- [x] Dispose/new session reset đúng và không leak callback/component.

## Prompt loop feature
Đọc task và dependencies; viết transition table rồi implement TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi transition/reentrancy/lifecycle/error; analyze/test root + example; smoke Android device thật chứng minh pause/background/win/restart. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Implementation evidence

- Added `GameSessionController` with typed phases, typed validation rejection, terminal-state protection, restart reset and reactive snapshots.
- Added nested user/system pause reasons so resume only returns to playing after every active reason clears.
- Bridged `RoyLifecycleCoordinator` background/resume events and removed the lifecycle hook on controller disposal.
- Added unit, widget and consumer integration coverage for valid/invalid transitions, terminal behavior, nested pauses, lifecycle bridge and cleanup.
- Root analyze/full suite passed: **660 tests**. Example analyze/full suite passed: **30 tests**.
- Android smoke passed on physical Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36); evidence: `doc/task/evidence/FEAT-41-device-smoke.log`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
