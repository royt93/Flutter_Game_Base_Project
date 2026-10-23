---
id: FEAT-187
title: ConsentPreferencesPanel — Ongoing category consent controls
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Privacy, Sync and Battery UI (Wave 24)
---

## Phạm vi
- Caller supplies category id/label/description/status; `ConsentPreferencesPanel` does not access storage or `ConsentStateService`.
- Shows granted/denied/unknown explicitly. Equal-weight Allow/Don't allow actions call the exact id and next status. Existing choice is disabled. No choice is preselected for unknown.
- Pending callback locks all rows; generic error copy. Caller owns policy and persistence.

## Kiểm chứng
- [x] Unit/widget tests, showcase host test and Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke pass; showcase callbacks are in-memory only.
- [ ] Linux + Flutter 3.35.1 goldens for unknown, denied and busy × 7 variants.
- [ ] Root/example suites, analyzers, API compatibility, quality gates and CI.
