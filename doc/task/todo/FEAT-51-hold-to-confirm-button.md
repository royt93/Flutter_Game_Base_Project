---
id: FEAT-51
title: "HoldToConfirmButton — giữ để xác nhận hành động rủi ro"
type: feature
layer: presentation/widget
priority: P1
effort: S
depends_on: [FEAT-50, IDEA-41]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người dùng, tôi muốn hành động reset/delete/purchase chỉ chạy sau khi giữ đủ lâu để tránh chạm nhầm.

## Sprint slices
- Press/drag/cancel state machine và radial/linear progress animation.
- Haptic milestones optional, keyboard/semantics activation alternative.
- Config duration, label và reset curve; reduced motion vẫn giữ thời gian an toàn.

## Acceptance criteria
- [ ] Giữ đủ gọi confirm đúng một lần; thả/drag ra/unmount sớm không gọi.
- [ ] Multi-pointer/rage tap/reentrant callback không double fire.
- [ ] Disabled, keyboard và screen-reader path có contract truy cập được.
- [ ] Animation/haptic mượt và reduced motion không bỏ protection.

## Prompt loop feature
Đọc task và interaction conventions; TDD gesture state machine. End loop: audit, chấm /10; unit test + widget test + integration test mọi gesture/multitouch/a11y/dispose; analyze/test root + example; smoke Android device thật quay thao tác chứng minh. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

