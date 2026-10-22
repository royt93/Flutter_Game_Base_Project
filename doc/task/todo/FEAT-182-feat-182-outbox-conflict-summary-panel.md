---
id: FEAT-182
title: OutboxConflictSummaryPanel — Opaque manual-review conflict choices
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Offline Delivery UI (Wave 21)
---

## Need
`OfflineOutboxService.manualReviewItems` can hold plaintext payloads and keys that may encode domain data. A reusable review panel must show only caller-approved labels and opaque references.

## Scope
- Immutable safe summary: opaque reference, local/remote labels, optional timestamp text.
- Duplicate or blank references reject at runtime.
- Keep-local and accept-remote both require inline confirmation. Cancel does not call back. Accept-remote copy says it removes the queued change and does not undo local effects.
- Parent maps reference to key and calls `resolveManual`; widget stays presentation-only.
- Busy/reference changes clear stale selection; callback errors use generic copy.

## DoD
- [x] Widget tests: privacy markers absent, both resolutions, cancel, multi-reference isolation, busy/reference invalidation, error path and duplicate refs.
- [x] 320dp + 200% RTL layout/semantics test.
- [x] Showcase uses stable opaque refs and generic labels; no payload/key rendering.
- [x] Golden matrix empty/pending/keep-local/accept-remote × 7 locally validates layout/guidelines; Linux PNGs pending.
- [x] TECNO KJ7 smoke covers cancel, keep-local, accept-remote and opaque references.
- [x] Root tests (3,213 non-golden), example tests (305), analyzers, API and quality gates pass.
- [ ] Linux goldens, CI run and clean commit pending.
