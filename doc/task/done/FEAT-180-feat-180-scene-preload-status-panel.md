---
id: FEAT-180
title: ScenePreloadStatusPanel — Trạng thái preload scene do caller sở hữu
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Content Delivery Readiness (Wave 20)
---

## Vì sao cần
`AssetPreloadCoordinator` cung cấp `progressOf`, preload/retry/cancel và `SdkResult`, nhưng không public failed IDs. Consumer cần panel an toàn để trình bày kết quả và hành động mà không lộ manifest, path hoặc lỗi loader.

## Phạm vi
- Props: `sceneId`, enum `idle/loading/ready/error/cancelled`, `progress` hữu hạn 0..1, `itemCount >= 0`, busy, optional start/retry async và cancel sync.
- Ready chỉ khi caller báo; progress 100% không suy ra thành công. Không hiện failed IDs, manifest, path hay raw error.
- Action chỉ hiện đúng trạng thái; start/retry bị khóa khi busy/in-flight; callback throw chỉ hiện generic copy.
- Đổi scene/status/busy hủy lỗi stale; completion cũ không áp lỗi lên scene mới.

## DoD
- [x] Widget tests: input validation, each status/action, retry/cancel, busy, error sanitization, double tap, stale scene completion.
- [x] Layout: 320dp + 200% RTL; golden matrix accessibility/layout guidelines pass locally.
- [x] Showcase caller-owned local demo; host test confirms idle → ready and progress 1.
- [x] TECNO KJ7 smoke confirms preload start and ready state.
- [x] Linux + Flutter 3.35.1 golden matrix idle/loading/error/ready × 7; 28 PNGs in commit `5fd3005`, lockfiles unchanged.
- [x] Root/example suites (3,206/304), analyzers, API, all quality gates and publish dry-run pass; CI `39770438468` green.
