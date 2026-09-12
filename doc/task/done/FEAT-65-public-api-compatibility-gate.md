---
id: FEAT-65
title: "Public API Compatibility Gate"
type: feature
layer: SDK release
priority: P0
effort: S
depends_on: [ENH-56]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
CI phát hiện breaking change trên public exports, yêu cầu semver và changelog trước merge.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] API snapshot được tạo và diff ổn định.
- [x] Breaking/additive/deprecation được phân loại đúng.
- [x] CI fail đúng khi version/changelog không phù hợp và pass khi migration hợp lệ.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Implementation evidence

- Added deterministic `tool/api_snapshot.json` generated from the stable public entrypoint exports and public declarations.
- Added `tool/api_compatibility.dart` with `snapshot` and `check` commands. The gate reports unchanged/additive/breaking changes and requires a changelog section or breaking version policy accordingly.
- Added unit/process tests for snapshot presence, gate execution and widget compatibility; CI now runs the gate before analyze/test.
- Public API documentation in README states the supported entrypoint and migration policy for deep imports.
- Root and `example/` passed `flutter analyze` and `flutter test --exclude-tags slow` (root: 640 tests; example: 31 tests).
- `dart pub publish --dry-run` completed; existing package layout warnings are documented separately and do not affect gate behavior.
- Device smoke `app boots to HomeScreen` passed on Samsung SM S928B (`R5CX613VZBR`, Android 16/API 36) with the migrated public bootstrap; raw output is stored at `doc/task/evidence/FEAT-65-device-smoke.log`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.
