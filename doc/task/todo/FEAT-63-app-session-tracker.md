---
id: FEAT-63
title: "AppSessionTracker — session id, install/session count và foreground duration"
type: feature
layer: app/core
priority: P2
effort: S
depends_on: [FEAT-33, FEAT-37, FEAT-61]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là product developer, tôi muốn metadata session nhất quán cho analytics/review/onboarding mà không để mỗi feature tự đếm.

## Sprint slices
- Immutable current session: random id, sequence, first install/open, start/resume times.
- Persist install/session counters nguyên tử; foreground duration dùng monotonic time.
- Lifecycle integration, analytics context provider và consent gate.
- Clock/process restart/corrupt state policy.

## Acceptance criteria
- [ ] Một process session có một id; cold start tăng count đúng một lần.
- [ ] Background không tính vào foreground duration; resume không tạo session mới ngoài policy.
- [ ] Corrupt/negative counters recover không crash và không giảm sequence đã tin cậy.
- [ ] Khi chưa analytics consent, tracker không tự gửi event/PII.

## Prompt loop feature
Đọc task/lifecycle/consent dependencies; TDD timeline/restart fixtures. End loop: audit, chấm /10; unit test + widget test + integration test mọi cold/warm start/background/corrupt/consent; analyze/test root + example; smoke Android device thật với force-stop/relaunch log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
