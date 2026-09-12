---
id: FEAT-38
title: "SdkResult và lỗi typed thống nhất cho public API"
type: feature
layer: core
priority: P1
effort: M
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là consumer, tôi muốn xử lý lỗi SDK theo code/retryability thay vì đoán exception hoặc gặp silent failure.

## Sprint slices
- Sealed result success/failure và taxonomy validation/storage/platform/network/conflict.
- Giữ cause + stack trace nội bộ; public message không chứa secret/PII.
- Mapping convention cho API mới; migration có chọn lọc cho service cũ.
- Analytics/crash hooks nhận structured failure.

## Acceptance criteria
- [x] Pattern match exhaustive, typed payload và equality/toString an toàn.
- [x] Stack trace/cause không mất; retryable được xác định rõ.
- [x] Ít nhất hai service khác loại dùng model nhất quán.
- [x] Migration không phá API public ngoài phần đã document.

## Prompt loop feature
Đọc task và error paths; implement tối thiểu bằng TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi success/error/mapping/redaction; analyze/test root + example; smoke device thật chứng minh UI xử lý lỗi typed. Lặp đến work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.

## Implementation evidence

- Added sealed `SdkResult<T>` with typed `SdkSuccess<T>` and `SdkFailure<T>` taxonomy, retryability, safe public message, preserved cause/stack trace, and safe equality/toString.
- Added `VersionedJsonStore.loadResult()` and `RemoteConfigService.initResult()` adapters while preserving existing APIs.
- Added unit, widget and consumer integration coverage for success/failure mapping, redaction, diagnostics and typed error UI.
- Root analyze/full suite passed: **656 tests**. Example analyze/full suite passed: **30 tests**.
- Android smoke passed on physical Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36); evidence: `doc/task/evidence/FEAT-38-device-smoke.log`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
