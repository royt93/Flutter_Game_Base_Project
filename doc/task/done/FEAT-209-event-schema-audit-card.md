---
id: FEAT-209
title: EventSchemaAuditCard — Aggregate-only analytics schema diagnostics
type: feature
priority: P2
effort: S
source: Analytics schema audit UI (Wave 33)
---

## Phạm vi
- Caller supplies aggregate total/rejected/redacted counts. Card never receives `EventAuditRecord`, event names, parameter names, schema declarations, values, or raw violation strings.
- Displays empty state and aggregate counts with explicit note that schema validation does not prove analytics delivery.
- Read-only presentation widget; no service/GetX access or actions.

## Kiểm chứng
- [x] 7 focused widget tests, Wave 33 showcase host test, root 3,484/example 316 non-golden tests, analyzers and five quality gates pass; API compatibility unchanged.
- [x] 21 Linux + Flutter 3.35.1 PNG baselines (3 states x 7 variants) imported from workflow 40065228127; lockfiles untouched, PR #37 closed unmerged.
- [x] CI 40065468318 (`analyze-test`, `quality-gate`, `consumer-smoke`) passes on `3fc4875`.
- [x] 2026-10-24: TECNO KJ7 passes 'Wave 33: analytics schema audit aggregate summary' in `example/integration_test/app_boot_test.dart` with `E2E_TEST=true`. The earlier `+0` was a selector mismatch (`--name` did not match); exact selector `--name='Wave 33'` passes. Evidence covers UI/count rendering only, not analytics delivery.
