---
id: FEAT-35
title: "RetryPolicy — timeout, exponential backoff và jitter inject được"
type: feature
layer: core/utils
priority: P1
effort: M
depends_on: [FEAT-34]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là developer, tôi muốn cloud save/config/analytics retry nhất quán mà không copy vòng lặp delay.

## Sprint slices
- Immutable policy: attempts, timeout, base/max delay, jitter, predicate.
- Clock/delay/random inject được để test deterministic.
- Typed attempt result và hook quan sát retry; hỗ trợ cancel.
- Ví dụ tích hợp RemoteConfig hoặc CloudSave, không hardcode vào service.

## Acceptance criteria
- [ ] Tính delay/cap/jitter đúng và không overflow với cấu hình biên.
- [ ] Chỉ retry lỗi được phép; success, non-retryable, timeout và cancel dừng đúng.
- [ ] Không retry vô hạn, không nuốt stack trace cuối.
- [ ] Integration chứng minh một service phục hồi sau lỗi transient.

## Prompt loop feature
Đọc task và code liên quan; TDD toàn bộ state machine. End loop: audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; analyze/test root + example; smoke Android device thật với fake/transient network và log attempts. Lặp đến work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.
