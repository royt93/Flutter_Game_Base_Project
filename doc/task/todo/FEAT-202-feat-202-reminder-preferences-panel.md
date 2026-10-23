---
id: FEAT-202
title: ReminderPreferencesPanel — Caller-owned reminder preferences
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Config, Reminder and Connectivity Status (Wave 29)
---

## Phạm vi
- Caller supplies enabled state and interval options; widget does not access `ReminderService`.
- State copy says delivery depends on notification permission and may be delayed/skipped; never claims a reminder is scheduled or guaranteed.
- Callback failure is generic; displayed choice remains caller-owned.

## Kiểm chứng
- [x] Widget tests, showcase host, TECNO KJ7 smoke, root 3,408/example 313 tests, analyzers, API compatibility and 5 quality gates pass.
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
