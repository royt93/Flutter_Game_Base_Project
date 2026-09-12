---
id: FEAT-54
title: "LevelUpOverlay — XP fill, level transition và reward reveal"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-43, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn khoảnh khắc level-up rõ ràng, vui và phản ánh đúng reward đã commit.

## Sprint slices
- Data-driven overlay nhận before/after XP, crossed levels và reward summary.
- Sequence XP fill→level pop→reward reveal→dismiss; queue multi-level.
- Confetti/haptic optional; reduced motion và skip animation.

## Acceptance criteria
- [ ] Một hoặc nhiều level-up render đúng thứ tự, không tự grant reward trong widget.
- [ ] Dismiss/skip/rebuild không gọi completion trùng.
- [ ] Overflow reward list/text scale/RTL có layout an toàn.
- [ ] Animation celebration dùng curve đúng và reduced motion hoạt động.

## Prompt loop feature
Đọc task/progression/reward code; TDD timeline và callbacks. End loop: audit, chấm /10; unit test + widget test + integration test single/multi-level/skip/dispose/a11y; analyze/test root + example; smoke Android device thật có screenshot/video. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

