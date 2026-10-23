---
id: FEAT-191
title: PlatformCapabilityMatrix — Read-only platform support list
type: feature
priority: P2
effort: XS
source: Scrum Master Epic: Operational Status Widgets (Wave 25)
---

## Phạm vi
- Caller maps `PlatformCapabilitySnapshot` to platform label and capability rows. Support is shown by icon and text, never colour alone.
- Always shows that values are platform defaults, not a live capability check.
- Empty rows, duplicate labels and blank copy fail at runtime. No callbacks.

## Kiểm chứng
- [x] Widget tests: validation, supported/unsupported text, disclaimer, 320dp + 200% RTL semantics.
- [x] Showcase uses the registered registry snapshot; golden layout checks pass.
- [ ] Linux + Flutter 3.35.1 PNG baselines.
- [x] Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke passes; root 3,364 and example 309 tests, analyzers, API compatibility and 5 quality gates pass locally.
- [ ] CI verification.
