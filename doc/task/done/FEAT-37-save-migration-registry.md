---
id: FEAT-37
title: "SaveMigrationRegistry — migration tuần tự và rollback an toàn"
type: feature
layer: data/core
priority: P0
effort: M
depends_on: [BUG-35, BUG-36, ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là maintainer, tôi muốn khai báo `v1→v2→v3` riêng biệt để nâng save lâu đời có kiểm soát.

## Sprint slices
- Registry immutable theo `(fromVersion, toVersion)` và validate chain lúc boot.
- Chạy migration trên bản copy, validate output từng bước, chỉ commit khi hoàn tất.
- Backup last-known-good/quarantine corrupt payload và diagnostic result.
- Adapter cho `VersionedJsonStore` giữ compatibility API hiện tại.

## Acceptance criteria
- [x] Multi-hop migration đúng thứ tự; missing/duplicate/future step fail rõ ràng.
- [x] Một bước throw/invalid không ghi đè save gốc.
- [x] Migration idempotent theo contract và không mutate input map.
- [x] Save từ các schema fixture cũ được integration test qua restart.

## Prompt loop feature
Đọc task và storage/versioning code; TDD fixtures trước implementation. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi chain/corrupt/rollback/restart; analyze/test root + example; smoke Android device thật với upgrade fixture và bằng chứng. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Implementation evidence

- Added immutable `SaveMigrationRegistry` and `SaveMigrationStep` with duplicate, backwards, future-step and missing-hop validation.
- Migrations run on deep copies at every hop, preserving caller input and leaving the original stored payload untouched when a step fails.
- `VersionedJsonStore` accepts an optional registry adapter and safely rejects migration exceptions during load.
- Added unit, widget and consumer integration coverage for multi-hop order, invalid chains, thrown steps, non-mutation and restart-style legacy fixture loading.
- Root analyze/full suite passed: **653 tests**. Example analyze/full suite passed: **30 tests**.
- Android smoke passed on physical Samsung SM-S928B (`R5CX613VZBR`, Android 16/API 36) with legacy schema upgrade; evidence: `doc/task/evidence/FEAT-37-device-smoke.log`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.
