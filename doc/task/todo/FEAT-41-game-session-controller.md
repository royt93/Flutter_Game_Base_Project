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
- [ ] Mọi state/event có transition hoặc typed rejection rõ; terminal state không tự thoát.
- [ ] System pause và user pause lồng nhau không resume sớm.
- [ ] Rapid/reentrant commands không phát event trùng.
- [ ] Dispose/new session reset đúng và không leak callback/component.

## Prompt loop feature
Đọc task và dependencies; viết transition table rồi implement TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi transition/reentrancy/lifecycle/error; analyze/test root + example; smoke Android device thật chứng minh pause/background/win/restart. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

