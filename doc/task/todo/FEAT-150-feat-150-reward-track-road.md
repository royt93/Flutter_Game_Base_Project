---
id: FEAT-150
title: RewardTrackRoad — Đường tiến độ XP với mốc quà free và premium
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Shop, Events & Retention UI (Wave 12)
---

## Vì sao cần
Season pass và progression track cần cho thấy XP hiện tại, mốc tiếp theo và quà free/premium phía trước. Một đường tiến độ tái sử dụng giúp consumer game thể hiện giá trị track mà không nhúng logic cấp thưởng vào UI.

## Đề xuất phạm vi
Widget `RewardTrackRoad` hiển thị:
- XP hiện tại, mốc tiers do caller cung cấp, progress tới mốc kế tiếp, và quà ở từng tier.
- Phân biệt quà free/premium và trạng thái locked/claimable/claimed theo props.
- Tap mốc gọi `onTierTap(tierId)`; nút claim (nếu có) gọi `onClaim(tierId)`.
- Danh sách dài render lazy; widget không tự kiểm tra entitlement/premium ownership hoặc cấp quà.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate tier IDs duy nhất, XP không âm, mốc tăng đơn điệu.
- [ ] **Widget test**: Progress/milestones, free/premium, locked/claimable/claimed và callbacks; semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro cuộn track, chạm mốc/claim gọi caller seam; không dùng simulator.
- [ ] **Golden test**: Đầu/giữa/cuối track, premium locked/unlocked trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rebuild/unmount khi animation tiến độ chạy không gọi claim lặp hoặc rò ticker.
- [ ] **Network conditioning test**: N/A — claim/entitlement thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog trên track dài sau scroll/unmount.
- [ ] **Frame rate / Jank test**: Scroll track 30+ tier; báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — không gọi purchase SDK.

## Hiệu năng & Animation
- [ ] Lazy row/tier rendering; animation tiến độ ngắn và tuân Reduced Motion.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
