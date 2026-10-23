---
id: FEAT-201
title: RemoteConfigHealthCard — Safe source and schema-count diagnostics
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Config, Reminder and Connectivity Status (Wave 29)
---

## Phạm vi
- Caller maps remote config source and schema violation count; never pass keys, values, schema violation strings or a service.
- Remote failure says bundled fallback is in use; violations reveal only count.
- Optional caller refresh callback uses generic failure copy and in-flight lock.

## Kiểm chứng
- [x] Widget tests, showcase host, TECNO KJ7 smoke, root 3,408/example 313 tests, analyzers, API compatibility and 5 quality gates pass.
- [x] 21 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39933038754; lockfiles untouched.
- [x] CI 39933455167 (analyze-test, quality-gate, consumer-smoke) passes on `93b9168`.
