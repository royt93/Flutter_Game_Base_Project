---
id: FEAT-49
title: "GameTimeController — pause, time-scale và deterministic tick"
type: feature
layer: game/logic
priority: P0
effort: M
depends_on: [FEAT-41, FEAT-45]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn gameplay clock riêng với wall clock để pause/slow-motion/replay không làm sai timer.

## Sprint slices
- Pure clock state elapsed/delta/scale/paused và injectable tick source.
- Clamp invalid/huge delta, fixed-step optional và deterministic advance cho test.
- Bridge Flame update loop và GetX snapshot cho Flutter countdown.
- Lifecycle/session pause ownership rõ, tránh double pause/resume.

## Acceptance criteria
- [ ] Pause đóng băng elapsed; resume không cộng thời gian background.
- [ ] Time scale hợp lệ, invalid input không poison state.
- [ ] Cùng tick sequence/seed cho cùng simulation result.
- [ ] Flame và Flutter observer thấy cùng game time không drift đáng kể.

## Prompt loop feature
Đọc task/session/RNG dependencies; TDD timeline matrix trước bridge. End loop: audit changes, chấm /10; unit test + widget test + integration test pause/scale/fixed-step/lifecycle; analyze/test root + example; smoke Android device thật với pause/background/slow-motion proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
