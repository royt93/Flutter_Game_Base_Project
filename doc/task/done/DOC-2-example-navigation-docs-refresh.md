---
id: DOC-2
title: "Đồng bộ hướng dẫn example với screen và đường dẫn navigation hiện tại"
type: docs
layer: README/CLAUDE/example
priority: P2
effort: S
source: "Full source audit 2026-11-21; docs may describe fewer screens and outdated demo navigation"
---

## Bằng chứng cần xác minh

Tài liệu repo mô tả ít screen hơn hiện có; reviewer flow có thể lệch đường dẫn trong Home. Trước khi sửa, xác minh thực tế từ `HomeScreen` và route definitions, không dựa vào số screen cứng.

- `CLAUDE.md` project/app overview
- `README.md`
- `example/README.md`
- `example/lib/screens/home_screen.dart`

## Phạm vi

Cập nhật danh sách/mô tả và shortest verified navigation flow; không viết lại docs ngoài vùng stale. Giữ README hướng dẫn contributor/reviewer ngắn, không khẳng định feature backend từ demo.

## Acceptance criteria

- [x] Mọi route/screens được nêu đều khớp code hiện tại; reviewer path đi qua Home → MiniGameHubScreen → Classic Flame.
- [x] Không có link hoặc command mới sai; demo/local seam không bị mô tả như production backend integration.
- [x] Markdown/path review pass; widget/integration tests không áp dụng vì docs-only.
- [x] Audit diff và điểm >9/10 theo rubric 10 điểm: accuracy 5, completeness 2, scope 1, reproducibility 1, evidence/checks 1.
- [x] UI/device smoke không áp dụng vì runtime behavior không đổi.

## Prompt loop

Đối chiếu từng câu mô tả example/navigation với `HomeScreen`, routes và README hiện tại; xác nhận bằng source route và test hiện có. Sửa docs tối thiểu, giữ claims chính xác về mock/seam/backend. Chạy doc/link checks sẵn có; nếu không có, rà soát link/path bằng shell read-only. Chấm theo rubric 10 điểm (accuracy 5, completeness 2, scope 1, reproducibility 1, evidence/checks 1); chỉ kết luận pass nếu >9/10. Dừng nếu khác biệt là thiết kế có chủ ý hoặc reviewer flow chưa rõ, ghi câu hỏi cụ thể cho owner. Không push riêng docs nếu điểm <=9; nếu >9 và mọi acceptance đạt, ghi kết quả rồi push theo yêu cầu owner.

## Kết quả thực hiện

- Navigation verified (2026-11-21): Home `Game Demo` → `MiniGameHubScreen` → `Classic Flame` → `GameDemoScreen`; Home also links directly to Widget Kit, Cookbook and other demo screens. Current screen files live in `example/lib/screens/`; docs avoid hard-coded screen counts.
- Audit / điểm: **9.5/10** — accuracy 5/5; completeness 2/2; scope 1/1; reproducibility 1/1 (route rõ từ Home qua hub); evidence/checks 0.5/1 (cross-check source paths + `git diff --check`, không có automated doc-link checker). Pass threshold >9/10.
- Checks: routes and paths cross-checked against source; `git diff --check` pass. No widget/integration run because docs-only.
- Device evidence: not applicable; no runtime/code changes.
- Commit/push: not committed/pushed; task remains in `todo` pending next choice.
