---
id: FEAT-193
title: SessionTimelineInspector — Bounded caller-safe phase history
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Session and Trust Inspection (Wave 26)
---

## Phạm vi
- Caller supplies formatted session-relative offset, phase label and optional caller-approved detail. Widget never accepts controller or raw timeline entry/metadata.
- Read-only with empty state, optional duration/terminal labels, and a configurable positive cap. Oldest rows are hidden when over cap.
- Runtime text/cap validation; narrow RTL/text-scale support.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,374 and example 310 suites, analyzers, API compatibility and 5 quality gates pass.
- [ ] Reachable-device smoke (S24 Ultra not connected; TECNO foreground app was a benchmark and was not interrupted).
- [ ] Linux + Flutter 3.35.1 goldens for empty/history × 7 variants.
- [ ] Full suites, analyzers, API compatibility, quality gates and CI.
