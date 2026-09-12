---
id: FEAT-57
title: "RetryErrorState — error UI chuẩn với retry và diagnostic code"
type: feature
layer: presentation/widget
priority: P0
effort: S
depends_on: [FEAT-38, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người dùng, tôi muốn lỗi tải/sync/offline có thông báo và retry nhất quán thay vì màn hình trắng.

## Sprint slices
- Data-driven icon/title/message/code và retry async action.
- Mapping presentation từ typed SDK error, cho phép copy diagnostic code.
- Compact/fullscreen variants, offline action slot và semantics live region.

## Acceptance criteria
- [ ] Retry loading/success/failure và rapid tap không chạy trùng.
- [ ] User message không lộ exception/secret; diagnostic code ổn định.
- [ ] Không có retry callback thì UI không giả tương tác.
- [ ] Text scale/RTL/reduced motion và screen reader đạt chuẩn.

## Prompt loop feature
Đọc task/error model; implement TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi variant/retry/error/accessibility; analyze/test root + example; smoke Android device thật với offline→online proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
