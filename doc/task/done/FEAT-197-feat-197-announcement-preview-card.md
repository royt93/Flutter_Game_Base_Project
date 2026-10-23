---
id: FEAT-197
title: AnnouncementPreviewCard — Caller-resolved screen-reader preview
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Debug QA and Rewarded-Ad UI (Wave 27)
---

## Phạm vi
- Caller supplies exact localized message, locale/category/throttle labels, and callback to trigger announcement through its own announcer.
- No GameEventBus, announcer, or translation-map dependency. Callback error copy is generic.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,386 and example 311 suites, analyzers, API compatibility and 5 quality gates pass.
- [x] 14 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39914597588; lockfiles untouched.
- [x] CI 39914900027 (analyze-test, quality-gate, consumer-smoke) passes on `7a7c03d`.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 27: debug status and rewarded-ad state on device' in `example/integration_test/app_boot_test.dart` with `E2E_TEST=true`. UI/callback fixture evidence only, not a platform screen-reader announcement.
