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
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
- [ ] Physical-device smoke not run: S24 Ultra unavailable; TECNO foreground app was a benchmark and was not interrupted.
