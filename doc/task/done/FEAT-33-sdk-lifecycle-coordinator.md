---
id: FEAT-33
title: "SDK LifecycleCoordinator — một nơi xử lý background/resume cho mọi module"
type: feature
layer: core
priority: P0
effort: M
depends_on: [FEAT-32]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là consumer, tôi muốn SDK tự điều phối lifecycle để audio, save, energy và config không bị mỗi app xử lý khác nhau.

## Sprint slices
- GetX service làm `WidgetsBindingObserver`, phát immutable lifecycle state.
- Background: pause audio, flush buffered storage, yêu cầu checkpoint.
- Resume: resume audio, refresh time-derived services và optional remote config.
- Hook có thứ tự, timeout, isolation lỗi và dispose sạch.

## Acceptance criteria
- [x] Mỗi transition hợp lệ chạy hook đúng một lần theo thứ tự đã document.
- [x] Một hook lỗi/timeout không chặn cleanup quan trọng còn lại.
- [x] Init/dispose nhiều lần không leak observer hoặc callback.
- [x] Example bỏ lifecycle wiring trùng và hành vi hiện tại không regression.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD. End loop bắt buộc: audit code changes và chấm /10; bổ sung unit test + widget test + integration test cho mọi transition, timeout, lỗi và dispose; analyze/test root + example; smoke test Android device thật bằng log background/resume. Nếu work hoặc điểm chưa >9/10 thì lặp tiếp. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, commit + push lần hai.

## Implementation evidence

- Added `RoyLifecycleCoordinator` as a GetX `WidgetsBindingObserver` with ordered hooks, one dispatch per effective transition, timeout isolation, failure reporting, and observer cleanup.
- Background dispatch pauses audio and flushes buffered storage; resume dispatch resumes audio before consumer hooks.
- Added unit, widget, and consumer integration coverage for ordering, deduplication, errors, timeout, foreground/background state, and dispose behavior.
- Root analyze/full suite passed: **646 tests**. Example analyze/full suite passed: **30 tests**.
- Android smoke passed on physical Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36); evidence: `doc/task/evidence/FEAT-33-device-smoke.log`. Pixel 7 Pro (`2B051FDH3006MU`) was unavailable.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
