---
id: FEAT-70
title: "SDK Diagnostics Export Bundle"
type: feature
layer: core/debug
priority: P2
effort: M
depends_on: [FEAT-39, IDEA-42]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Đóng gói health report, replay capsule, config và logs đã redact thành artifact support.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
[ ] Bundle có manifest/schema/version, size cap và checksum.\n- [ ] Secret/PII/raw save bị loại mặc định.\n- [ ] Export lỗi một phần vẫn đọc được phần còn lại và import chỉ read-only.
- [ ] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [ ] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

