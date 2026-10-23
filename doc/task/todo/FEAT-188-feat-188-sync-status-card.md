---
id: FEAT-188
title: SyncStatusCard — Caller-owned sync and retry state
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Privacy, Sync and Battery UI (Wave 24)
---

## Phạm vi
- Caller supplies idle/syncing/synced/failed state, optional last-synced text and sync callback; widget does not access achievement/leaderboard services.
- Busy/syncing prevents duplicate actions. Callback failure uses generic text, never an exception or server response. Success label follows externally updated status only.
- Supports achievement and leaderboard sync through caller mapping.

## Kiểm chứng
- [x] Unit/widget tests, showcase host test and Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke pass; showcase callbacks are in-memory only.
- [ ] Linux + Flutter 3.35.1 goldens for idle/syncing/synced/failed × 7 variants.
- [ ] Root/example suites, analyzers, API compatibility, quality gates and CI.
