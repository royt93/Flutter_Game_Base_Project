---
id: FEAT-199
title: AnalyticsQueueStatusCard — Aggregate-only privacy queue status
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Analytics Queue and Save Restore Preview (Wave 28)
---

## Phạm vi
- Caller supplies pending/uploaded/dropped aggregate counts and optional flush callback; no queue or analytics events enter widget.
- No event names, IDs or params rendered. Flush action is hidden when analytics consent is not granted.
- Busy/in-flight lock, generic errors, runtime non-negative counter validation.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,395 and example 312 suites, analyzers, API compatibility and 5 quality gates pass.
- [x] 21 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39928480292; lockfiles untouched.
- [x] TECNO KJ7 (`115333744A005844`) integration smoke passes aggregate status and flush flow.
- [x] CI 39928814646 (analyze-test, quality-gate, consumer-smoke) passes on `c37e944`.
