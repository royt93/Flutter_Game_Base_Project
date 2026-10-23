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
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 26: session timeline and trust summary on device' in `example/integration_test/app_boot_test.dart` with `E2E_TEST=true`. UI fixture evidence only, not live rollout-controller verification.
- [x] CI 39908353321 (analyze-test, quality-gate, consumer-smoke) passes on `f1b32df`.
