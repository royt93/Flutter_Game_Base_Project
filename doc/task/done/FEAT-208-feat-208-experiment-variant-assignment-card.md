---
id: FEAT-208
title: ExperimentVariantAssignmentCard — Caller-mapped experiment assignments
type: feature
priority: P2
effort: S
source: Onboarding and experiment inspection UI (Wave 32)
---

## Phạm vi
- Caller maps `variantFor` results to rows. The per-device `anonymousId` and the experiment key are never accepted for display.
- Override and clear actions exist only when the caller passes `onSelectOverride`; `debugSetVariantOverride` is a no-op in release, so the caller passes it only in debug or profile builds.
- Assigned variant must be one of the available variants; generic failure copy and an in-flight lock.

## Kiểm chứng
- [x] Widget tests (20), showcase host test, analyzers and API compatibility (snapshot refreshed) pass.
- [x] 49 Linux + Flutter 3.35.1 PNG baselines (7 states x 7 variants, shared by FEAT-207..208) imported from workflow 39957224354; lockfiles untouched, PR #35 closed unmerged.
- [x] CI 39957603046 (analyze-test, quality-gate, consumer-smoke) passes on `f86615f`.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 32: onboarding queue and experiment override' (`example/integration_test/app_boot_test.dart`, `E2E_TEST=true`). UI/callback fixture evidence only, not a real onboarding flow run or experiment bucketing proof.
