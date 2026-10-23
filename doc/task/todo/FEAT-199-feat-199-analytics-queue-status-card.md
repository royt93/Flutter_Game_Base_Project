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
- [ ] Widget tests, showcase host and device smoke if safe device available.
- [ ] Linux + Flutter 3.35.1 goldens, full suites, analyzers, API check, gates and CI.
