---
id: FEAT-204
title: RewardPlanPreviewCard — Preview-before-apply reward status
type: feature
priority: P1
effort: S
source: Reward and replay inspection UI (Wave 31)
---

## Phạm vi
- Caller supplies safe formatted reward lines and an explicit status (ready, stale, executing, applied, failed); no `RewardPlan`, fingerprint or receipt metadata enters the widget.
- Confirm only when ready; stale/failed offer refresh. A returning callback never sets applied: the caller maps `executePlan` to applied only for a committed record.
- Copy says a preview is not a grant. Generic failure copy and an in-flight lock.

## Kiểm chứng
- [x] Widget tests, showcase host test, analyzers and API compatibility (snapshot refreshed) pass.
- [ ] Linux + Flutter 3.35.1 golden baselines not generated yet.
- [ ] CI not run yet.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 31: reward preview, replay check and audit retry' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real reward grant, replay authenticity or fair-play proof.
