---
id: FEAT-50
title: "AsyncCommonButton — loading/success/error và chống double tap"
type: feature
layer: presentation/widget
priority: P0
effort: S
depends_on: [FEAT-34, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn nút async tự khóa, báo tiến trình/kết quả và không gọi action hai lần.

## Sprint slices
- API composable trên `CommonButton`, nhận async callback và optional external state.
- Animated label→spinner→success/error, timeout/retry policy optional.
- Semantics live status, disabled state và reduced motion.

## Acceptance criteria
- [ ] Rapid tap chỉ chạy một Future; thành công/lỗi/timeout về trạng thái đúng.
- [ ] Unmount trong lúc chờ không setState/callback sau dispose.
- [ ] Layout không nhảy width và hỗ trợ text scale/RTL.
- [ ] Animation theo NeonTheme, reduced motion collapse đúng.

## Prompt loop feature
Đọc task và CommonButton; implement TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi tap/success/error/timeout/dispose/accessibility; analyze/test root + example; smoke Android device thật có video/log. Lặp tới work và điểm >9/10 mới push; cập nhật Quyết định, chuyển done, push lần hai.

