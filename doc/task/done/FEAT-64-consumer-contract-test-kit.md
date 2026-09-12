---
id: FEAT-64
title: "Consumer Contract Test Kit"
type: feature
layer: SDK foundation
priority: P1
effort: M
depends_on: [ENH-56, FEAT-32]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tạo test harness để consumer kiểm tra bootstrap, lifecycle, storage, adapter và widget contract mà không copy boilerplate.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Harness chạy được trong app consumer và bắt sai registration/lifecycle contract.
- [x] Fixture fake deterministic, không phụ thuộc network/vendor.
- [x] Có unit, widget, integration và smoke example chứng minh lỗi thật bị bắt.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Implementation evidence

- Added `RoyCasualKitTestFixture` with deterministic in-memory storage and injectable `storageOverride`; the fixture does not require network or vendor SDKs.
- Added `RoyCasualKitContractTestKit.verifyBootstrap` and typed `RoyCasualKitContractReport` to check initialization errors, expected module registration, and idempotent repeated bootstrap.
- Added unit and widget coverage for passing contracts and actionable missing-module failures.
- Added consumer integration coverage in `example/integration_test/app_boot_test.dart`.
- Android smoke passed on Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36); evidence: `doc/task/evidence/FEAT-64-device-smoke.log`.
- `flutter analyze` and full root suite passed (`643` tests); example analyze and test suite passed (`31` tests).

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
