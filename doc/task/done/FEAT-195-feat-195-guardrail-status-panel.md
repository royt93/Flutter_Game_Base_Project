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
- [x] 14 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39908030941; lockfiles untouched.
- [ ] Physical-device smoke not run: S24 Ultra unavailable; TECNO foreground app was a benchmark and was not interrupted.
- [x] CI 39908353321 (analyze-test, quality-gate, consumer-smoke) passes on `f1b32df`.
