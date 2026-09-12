---
id: FEAT-81
title: "Remote Schema Compiler"
type: feature
layer: liveops/tooling
priority: P1
effort: L
depends_on: [ENH-58, IDEA-37, FEAT-37]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Compile/validate remote content schema thành typed Dart models và migration fixtures.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
[ ] Schema invalid/signature/version không tạo code hoặc content unsafe.\n- [ ] Generated model immutable, backward migration có test.\n- [ ] Asset fallback và generated content cho cùng fixture ra cùng semantic result.
- [ ] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [ ] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

