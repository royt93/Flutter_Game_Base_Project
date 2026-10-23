---
id: FEAT-195
title: GuardrailStatusPanel — Caller-owned rollout guardrail summaries
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Session and Trust Inspection (Wave 26)
---

## Phạm vi
- `ShadowActivationController` has no read API. Caller supplies feature/metric labels and noData/ok/violated state; optional formatted bounds/readings are explicitly opt-in.
- Read-only: no controller access, kill/clear actions or inferred state.
- Runtime text validation; narrow RTL/text-scale support.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,374 and example 310 suites, analyzers, API compatibility and 5 quality gates pass.
- [ ] Reachable-device smoke (S24 Ultra not connected; TECNO foreground app was a benchmark and was not interrupted).
- [ ] Linux + Flutter 3.35.1 goldens for empty/mixed-state × 7 variants.
- [ ] Full suites, analyzers, API compatibility, quality gates and CI.
