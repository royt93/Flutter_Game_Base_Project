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
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
- [ ] Physical-device smoke not run: S24 Ultra unavailable; TECNO foreground app was a benchmark and was not interrupted.
