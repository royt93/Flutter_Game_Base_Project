---
id: FEAT-83
title: "Privacy-aware Analytics Sampling"
type: feature
layer: analytics/core
priority: P1
effort: M
depends_on: [FEAT-61, FEAT-63, FEAT-77]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Sampling theo session/event, redaction và consent để giảm dữ liệu nhưng vẫn giữ funnel hữu ích.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
[ ] Chưa consent không emit; sampling deterministic theo session seed.\n- [ ] PII keys bị redact trước provider và queue.\n- [ ] Rate limit/backpressure không block gameplay và có audit count.
- [ ] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [ ] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

