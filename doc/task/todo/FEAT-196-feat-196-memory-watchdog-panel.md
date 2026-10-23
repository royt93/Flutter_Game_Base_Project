---
id: FEAT-196
title: MemoryWatchdogPanel — Read-only debug resource diagnostics
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Debug QA and Rewarded-Ad UI (Wave 27)
---

## Phạm vi
- Caller supplies safe rows from `MemoryWatchdog.orphans()` and `recentlyDisposed()`; widget never reads global watchdog state.
- Bounded row count, empty states, optional caller refresh callback with generic failure copy.
- Copy explicitly says debug-only, detector not prevention, no release-build reports.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,386 and example 311 suites, analyzers, API compatibility and 5 quality gates pass.
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
- [ ] Physical-device smoke not run: S24 Ultra unavailable; TECNO foreground app was a benchmark and was not interrupted.
