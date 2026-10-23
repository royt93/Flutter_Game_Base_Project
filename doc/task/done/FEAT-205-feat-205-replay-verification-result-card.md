---
id: FEAT-205
title: ReplayVerificationResultCard — Separate outcome and randomness check status
type: feature
priority: P2
effort: S
source: Reward and replay inspection UI (Wave 31)
---

## Phạm vi
- Outcome status and randomness status are separate; a skipped randomness check is shown as skipped, never matched.
- matched/diverged require a positive compared-outcome count, because replay only compares events carrying an expected outcome.
- No capsule, payload, secret, expected/actual value or RNG namespace is accepted; a malformed or tampered capsule maps to one generic invalid state. Not proof of fair play.

## Kiểm chứng
- [x] Widget tests, showcase host test, analyzers and API compatibility (snapshot refreshed) pass.
- [x] 63 Linux + Flutter 3.35.1 PNG baselines (9 states x 7 variants, shared by FEAT-204..206) imported from workflow 39951507281; lockfiles untouched, PR #34 closed unmerged.
- [x] CI 39951818473 (analyze-test, quality-gate, consumer-smoke) passes on `d0914e2`. An earlier run 39948133602 on `a701b78` failed: golden baselines were missing, and `consumer-smoke` timed out on the emulator (cause not diagnosed; it did not recur).
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 31: reward preview, replay check and audit retry' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real reward grant, replay authenticity or fair-play proof.
