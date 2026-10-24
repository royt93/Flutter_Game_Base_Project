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
- [ ] Linux + Flutter 3.35.1 golden baselines pending.
- [ ] CI pending.
- [ ] TECNO KJ7 integration command built/installed, but remained at `+0` for over 6 minutes with no Flutter exception or progress; runner stopped, no pass claimed. Needs runner diagnosis.
