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
- [ ] Linux + Flutter 3.35.1 golden baselines not generated yet.
- [ ] CI not run yet.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 31: reward preview, replay check and audit retry' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real reward grant, replay authenticity or fair-play proof.
