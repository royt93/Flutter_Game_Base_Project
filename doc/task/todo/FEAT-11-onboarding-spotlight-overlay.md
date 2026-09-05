---
id: FEAT-11
title: Onboarding/Tutorial spotlight overlay (CoachMark)
type: feature
priority: P2
effort: M
source: agy + claude-CLI
---

## Vì sao cần
Chưa có widget nào trong 21+9 widget hiện tại cho việc "highlight 1 vùng UI,
làm mờ phần còn lại, chỉ mũi tên hướng dẫn" — rất phổ biến ở màn hình
onboarding casual game.

## Đề xuất phạm vi
1 widget mới dùng chung `NeonDialog.overlay` pattern đã có (không cần route),
nhận vào `GlobalKey` của widget đích cần highlight + text hướng dẫn.

## Acceptance criteria
- [ ] Highlight đúng vị trí widget đích qua `GlobalKey`, dim phần còn lại màn hình.
- [ ] Widget test dựng overlay, verify đúng vị trí/kích thước vùng highlight.
