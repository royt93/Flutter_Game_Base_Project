---
id: FEAT-189
title: BatterySaverIndicator — Visible low-battery performance notice
type: feature
priority: P2
effort: XS
source: Scrum Master Epic: Privacy, Sync and Battery UI (Wave 24)
---

## Phạm vi
- Caller supplies active state and optional battery percentage (0–100); render nothing when inactive.
- No battery plugin, polling or `BatterySaverCoordinator` dependency. Caller owns reads and performance-tier changes.
- Live-region semantics only on the active banner.

## Kiểm chứng
- [x] Unit/widget tests, showcase host test and Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke pass; showcase callbacks are in-memory only.
- [ ] Linux + Flutter 3.35.1 goldens for inactive/active-with-percent/active-unknown × 7 variants.
- [ ] Root/example suites, analyzers, API compatibility, quality gates and CI.
