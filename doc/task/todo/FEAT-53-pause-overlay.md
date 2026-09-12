---
id: FEAT-53
title: "PauseOverlay — resume/restart/settings/quit nối GameSessionController"
type: feature
layer: presentation/widget
priority: P0
effort: M
depends_on: [FEAT-41, FEAT-49, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn pause overlay nhất quán và game chỉ resume khi đúng pause owner được giải phóng.

## Sprint slices
- Overlay-first panel dùng session state, action slots và confirm hook.
- Entrance/exit animation, focus trap, back behavior và audio/game-time coordination.
- Default resume/restart/settings/quit wiring có thể override.

## Acceptance criteria
- [ ] Hiện đúng khi user pause, không tự hiện cho mọi system pause nếu config không yêu cầu.
- [ ] Back/resume/restart/quit phát đúng command một lần.
- [ ] Overlay modal về pointer/semantics/focus và hoạt động trên Flame full-screen.
- [ ] Reduced motion, text scale và RTL đạt chuẩn.

## Prompt loop feature
Đọc task/session/dialog conventions; implement TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi action/back/focus/lifecycle; analyze/test root + example; smoke Android device thật trên Flame demo có video/log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

