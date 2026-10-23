---
id: FEAT-207
title: OnboardingFlowQueueCard — Read-only onboarding queue and seen state
type: feature
priority: P2
effort: S
source: Onboarding and experiment inspection UI (Wave 32)
---

## Phạm vi
- Caller maps `isFlowSeen`/`nextEligibleFlow` to rows; the widget never receives `OnboardingCoordinatorService` (whose registrations are private) or storage keys.
- Shows seen / next / not-seen state with priority and version. At most one row is next and ids must be unique; `flowId` only identifies a row in `onMarkSeen` and is never rendered.
- Optional mark-seen action with in-flight lock and generic failure copy; the caller updates the rows afterwards. Positive row cap with a hidden count.

## Kiểm chứng
- [x] Widget tests (20), showcase host test, analyzers and API compatibility (snapshot refreshed) pass.
- [x] 49 Linux + Flutter 3.35.1 PNG baselines (7 states x 7 variants, shared by FEAT-207..208) imported from workflow 39957224354; lockfiles untouched, PR #35 closed unmerged.
- [x] CI 39957603046 (analyze-test, quality-gate, consumer-smoke) passes on `f86615f`.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 32: onboarding queue and experiment override' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real onboarding flow run or experiment bucketing proof.
