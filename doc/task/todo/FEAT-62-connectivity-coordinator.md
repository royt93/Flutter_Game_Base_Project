---
id: FEAT-62
title: "ConnectivityCoordinator — reactive reachability và queue tác vụ khi offline"
type: feature
layer: app/data
priority: P1
effort: M
depends_on: [FEAT-34, FEAT-35, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn phân biệt có interface mạng với Internet dùng được và retry tác vụ an toàn khi online lại.

## Sprint slices
- Adapter interface cho connectivity signal và reachability probe inject được.
- State offline/checking/online/degraded với debounce/hysteresis.
- Bounded task queue có idempotency key, expiry, priority và retry policy.
- Bridge `NetworkStatusBanner` cùng lifecycle coordinator.

## Acceptance criteria
- [ ] Interface up nhưng probe fail không báo online giả.
- [ ] Flapping không spam UI/retry; lifecycle dispose không leak stream/timer.
- [ ] Queue không chạy task hết hạn/trùng và không vượt size cap.
- [ ] Online lại drain theo policy; một task lỗi không chặn task độc lập.

## Prompt loop feature
Đọc task/network banner/retry code; TDD fake streams/probes/queue. End loop: audit, chấm /10; unit test + widget test + integration test mọi connectivity/flap/queue/error/lifecycle; analyze/test root + example; smoke Android device thật bật/tắt airplane mode có log/video. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

