---
id: FEAT-192
title: DeepLinkResultCard — Generic deep-link outcome feedback
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Operational Status Widgets (Wave 25)
---

## Phạm vi
- Caller maps `DeepLinkHandleResult` to dispatched, queued, duplicate, rejected or handlerFailed. The widget never receives or renders URI, query parameters, router rejection message or handler exception.
- Retry exists only for rejected/handlerFailed when supplied; callbacks are locked while pending and use generic error copy.
- Status/busy changes invalidate stale errors; unmount is safe.

## Kiểm chứng
- [x] Widget tests: all statuses, no URI/token/error leakage, retry gating, busy/in-flight/unmount, 320dp + 200% RTL semantics.
- [x] Showcase uses an in-memory generic fixture; golden layout checks pass.
- [x] 35 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39901817579; lockfiles untouched.
- [x] Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke passes; root 3,364 and example 309 tests, analyzers, API compatibility and 5 quality gates pass locally.
- [x] CI 39902003927 (analyze-test, quality-gate, consumer-smoke) passes on `e6ab0ad`.
