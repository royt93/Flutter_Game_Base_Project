---
id: FEAT-179
title: ContentPackStatusCard — Trạng thái content pack do caller sở hữu
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Content Delivery Readiness (Wave 20)
---

## Vì sao cần
`RemoteContentPack` đã load/cache/refresh/rollback typed content, nhưng không có observable status API. Consumer cần UI trạng thái và hành động refresh mà không đưa typed payload hoặc checksum vào widget.

## Phạm vi
- Props caller-owned: enum `loading/ready/refreshing/error`, `contentVersion >= 0`, optional formatted updated-at, busy, optional async `onRefresh`.
- Không nhận `T`, raw JSON, checksum hoặc exception; không gọi `RemoteContentPack`, không suy ra freshness/integrity.
- Callback throw chỉ hiện generic copy; retry cần tap mới. Loading/refreshing/busy và in-flight chặn double tap.

## DoD
- [x] Widget tests: input validation, status/action mapping, busy/null callback, callback error sanitization, retry and single action.
- [x] Layout: 320dp + 200% RTL; golden matrix accessibility/layout guidelines pass locally.
- [x] Showcase caller-owned local demo; host test confirms refresh increments version.
- [x] TECNO KJ7 smoke confirms refresh callback increments version and ready status.
- [x] Root non-golden tests (3,206) + example tests (304), both analyzers, API, accessibility, SBOM, asset license, perf, deprecation, and publish dry-run pass.
- [ ] Linux golden PNG matrix pending; local macOS renders removed.
- [ ] CI pending Linux golden commit.
