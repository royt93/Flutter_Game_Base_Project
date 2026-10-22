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
- [x] Linux + Flutter 3.35.1 golden matrix ready/refreshing/error × 7; 21 PNGs in commit `5fd3005`, lockfiles unchanged.
- [x] Root/example suites (3,206/304), analyzers, API, all quality gates and publish dry-run pass; CI `39770438468` green.
