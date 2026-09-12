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
- [ ] Mỗi transition hợp lệ chạy hook đúng một lần theo thứ tự đã document.
- [ ] Một hook lỗi/timeout không chặn cleanup quan trọng còn lại.
- [ ] Init/dispose nhiều lần không leak observer hoặc callback.
- [ ] Example bỏ lifecycle wiring trùng và hành vi hiện tại không regression.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD. End loop bắt buộc: audit code changes và chấm /10; bổ sung unit test + widget test + integration test cho mọi transition, timeout, lỗi và dispose; analyze/test root + example; smoke test Android device thật bằng log background/resume. Nếu work hoặc điểm chưa >9/10 thì lặp tiếp. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, commit + push lần hai.

