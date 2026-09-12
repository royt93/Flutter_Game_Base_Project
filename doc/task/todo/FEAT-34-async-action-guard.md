---
id: FEAT-34
title: "AsyncActionGuard — single-flight và mutex theo key"
type: feature
layer: core/utils
priority: P0
effort: S
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là developer, tôi cần primitive dùng chung chống double-submit cho purchase, reward, sync và save.

## Sprint slices
- `runSingleFlight(key, action)` dùng chung Future đang chạy.
- `runExclusive(key, action)` xếp hàng tuần tự và phục hồi sau exception.
- Cleanup key sau complete/error/cancel; debug pending count.

## Acceptance criteria
- [ ] Hai single-flight cùng key chỉ chạy action một lần; khác key chạy độc lập.
- [ ] Exclusive giữ thứ tự và exception không wedge queue.
- [ ] Sync throw, async throw, reentrant call và cleanup đều có contract/test.
- [ ] Không giữ closure/key sau khi công việc kết thúc.

## Prompt loop feature
Đọc task và code liên quan; implement pure Dart bằng TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi case concurrency/error/reentrancy; analyze/test root + example; smoke test device thật qua luồng double-tap demo có log chứng minh. Lặp tới khi work và điểm >9/10 rồi mới commit + push; cập nhật Quyết định, chuyển done và push lần hai.

