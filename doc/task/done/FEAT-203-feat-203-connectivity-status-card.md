---
id: FEAT-203
title: ConnectivityStatusCard — Reachability state and waiting-task count
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Config, Reminder and Connectivity Status (Wave 29)
---

## Phạm vi
- Caller maps `ConnectivityState` and `queueLength`; widget does not receive coordinator or queued tasks.
- Says waiting tasks run automatically when online; no manual drain button because the coordinator has no such API.
- Optional retry check callback appears only for offline/degraded; generic failure copy and in-flight lock.

## Kiểm chứng
- [x] Widget tests, showcase host, TECNO KJ7 smoke, root 3,408/example 313 tests, analyzers, API compatibility and 5 quality gates pass.
- [x] 28 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39933038754; lockfiles untouched.
- [x] CI 39933455167 (analyze-test, quality-gate, consumer-smoke) passes on `93b9168`.
