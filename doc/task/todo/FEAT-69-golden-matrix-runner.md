---
id: FEAT-69
title: "Golden Matrix Runner"
type: feature
layer: tooling/widget
priority: P1
effort: M
depends_on: [ENH-37, ENH-38, ENH-40, FEAT-52]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tự render widget kit theo theme, locale, RTL, text scale và reduced motion.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
[ ] Matrix fixture deterministic, snapshot naming ổn định và diff dễ đọc.\n- [ ] Fail khi overflow/semantics/regression visual trong tổ hợp bắt buộc.\n- [ ] Có bounded runtime và CI artifact.
- [ ] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [ ] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

