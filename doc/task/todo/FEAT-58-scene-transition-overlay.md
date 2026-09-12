---
id: FEAT-58
title: "SceneTransitionOverlay — chuyển Flutter screen/Flame world có progress"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-41, FEAT-47, FEAT-57]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn chuyển scene mượt và thấy tiến trình/error thật khi asset đang tải.

## Sprint slices
- Transition controller/state idle→covering→loading→revealing/error.
- Fade/wipe builder, progress slot và retry/cancel command.
- Đồng bộ AssetPreload + GameSession; token chống completion cũ mở nhầm scene mới.

## Acceptance criteria
- [ ] Transition chỉ reveal khi đúng load token hoàn tất.
- [ ] Load lỗi/cancel/retry không kẹt lớp chắn pointer.
- [ ] Rapid navigation và widget dispose không callback stale.
- [ ] Animation mượt, modal semantics đúng và reduced motion hoạt động.

## Prompt loop feature
Đọc task/session/preload code; TDD state machine trước animation. End loop: audit, chấm /10; unit test + widget test + integration test mọi transition/race/error/dispose; analyze/test root + example; smoke Android device thật chuyển qua lại Flame scene có video/log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
