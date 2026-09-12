---
id: FEAT-84
title: "Disaster Recovery Save Export"
type: feature
layer: data/core
priority: P1
effort: M
depends_on: [FEAT-37, FEAT-39, IDEA-31]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tạo export encrypted/signed, multi-slot backup và restore preview trước apply.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
[ ] Export atomic, versioned, size-bounded và không lộ secret.\n- [ ] Restore preview validate toàn bộ; corrupt/tamper không mutate local save.\n- [ ] Crash giữa restore giữ last-known-good và có recovery log.
- [ ] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [ ] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

