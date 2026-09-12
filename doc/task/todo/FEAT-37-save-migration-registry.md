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
- [ ] Multi-hop migration đúng thứ tự; missing/duplicate/future step fail rõ ràng.
- [ ] Một bước throw/invalid không ghi đè save gốc.
- [ ] Migration idempotent theo contract và không mutate input map.
- [ ] Save từ các schema fixture cũ được integration test qua restart.

## Prompt loop feature
Đọc task và storage/versioning code; TDD fixtures trước implementation. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi chain/corrupt/rollback/restart; analyze/test root + example; smoke Android device thật với upgrade fixture và bằng chứng. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

