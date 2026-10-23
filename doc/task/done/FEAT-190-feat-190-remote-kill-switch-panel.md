---
id: FEAT-190
title: RemoteKillSwitchPanel — Confirmed device-local feature kill
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Operational Status Widgets (Wave 25)
---

## Phạm vi
- Caller maps current state to opaque id, label, killed flag, safe source label and optional sanitized reason text. Widget never receives the service or raw remote reason.
- A local kill requires inline confirm/cancel. It cannot enable remotely killed features. Clear appears only for an existing local override; caller maps this to `clearLocalOverride`.
- Busy/in-flight gate; generic failures; stale metadata clears selection/error.

## Kiểm chứng
- [x] Widget tests: validation, local confirm/cancel, no remote clear/re-enable, callback errors, in-flight/unmount, 320dp + 200% RTL/semantics.
- [x] In-memory showcase host and golden layout checks pass.
- [x] 21 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39901817579; lockfiles untouched.
- [x] Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke passes; root 3,364 and example 309 tests, analyzers, API compatibility and 5 quality gates pass locally.
- [x] CI 39902003927 (analyze-test, quality-gate, consumer-smoke) passes on `e6ab0ad`.
