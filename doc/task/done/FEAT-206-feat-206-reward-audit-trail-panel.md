---
id: FEAT-206
title: RewardAuditTrailPanel — Bounded reward audit rows and retry-all
type: feature
priority: P2
effort: S
source: Reward and replay inspection UI (Wave 31)
---

## Phạm vi
- Sanitized rows only: source, time, summary and pending/partial/committed status; no transaction id or receipt metadata.
- One retry-all action, enabled only while an unfinished row exists. `resumePending` retries every unfinished record and returns nothing, so completing it does not imply all committed; the caller refreshes the rows.
- Positive row cap with newest rows kept and a hidden count.

## Kiểm chứng
- [x] Widget tests, showcase host test, analyzers and API compatibility (snapshot refreshed) pass.
- [x] 63 Linux + Flutter 3.35.1 PNG baselines (9 states x 7 variants, shared by FEAT-204..206) imported from workflow 39951507281; lockfiles untouched, PR #34 closed unmerged.
- [x] CI 39951818473 (analyze-test, quality-gate, consumer-smoke) passes on `d0914e2`. An earlier run 39948133602 on `a701b78` failed: golden baselines were missing, and `consumer-smoke` timed out on the emulator (cause not diagnosed; it did not recur).
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 31: reward preview, replay check and audit retry' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real reward grant, replay authenticity or fair-play proof.
