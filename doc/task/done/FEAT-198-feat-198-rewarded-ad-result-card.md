---
id: FEAT-198
title: RewardedAdResultCard — Caller-owned ad status and watch action
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Debug QA and Rewarded-Ad UI (Wave 27)
---

## Phạm vi
- Caller maps `AdRewardSeam.isReady` / `showRewardedAd` to idle/notReady/loading/rewarded/cancelled/failed; widget never reads seam or grants reward.
- Reward text renders only when caller reports rewarded. Caller grants once using an idempotent transaction id only after ad seam returns true.
- Loading/busy disables action; callback errors are generic.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,386 and example 311 suites, analyzers, API compatibility and 5 quality gates pass.
- [x] 21 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39914597588; lockfiles untouched.
- [x] CI 39914900027 (analyze-test, quality-gate, consumer-smoke) passes on `7a7c03d`.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 27: debug status and rewarded-ad state on device' in `example/integration_test/app_boot_test.dart` with `E2E_TEST=true`. UI/callback fixture evidence only; not proof of real ad payout.
