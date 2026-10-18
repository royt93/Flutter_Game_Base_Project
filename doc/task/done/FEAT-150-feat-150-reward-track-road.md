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
- [x] **Unit test**: Validate XP không âm, tier IDs duy nhất, mốc XP tăng đơn điệu (`reward_track_road_test.dart`, 6 test pass).
- [x] **Widget test**: Track ngang, claim states, free/premium locked/enabled, claim callback, claimed state, semantics, Reduced Motion.
- [x] **Showcase test**: In-memory demo tăng XP, bật premium, và route claim callback (`FEAT-150: reward track advances XP, unlocks premium and routes claims`).
- [x] **Device smoke**: Pixel 7 Pro (`2B051FDH3006MU`) xác nhận premium toggle, scroll đến reward cell, và claim callback trên app thật.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) kiểm tra premium unlock và claim callback trên showcase thật; pass, không dùng simulator.
- [x] **Golden test**: Track 5 tier, premium locked/unlocked, mid/late XP trên baseline/dark/vi/RTL/textScale/reducedMotion. Golden bắt overflow ở textScale 2.0; tăng chiều cao track theo text scale.
- [x] **Interruption test**: N/A — widget không giữ timer/controller; progress/action state thuộc caller.
- [x] **Network conditioning test**: N/A — claim/entitlement thuộc caller.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-150.
- [ ] **Frame rate / Jank test**: CHƯA ĐO scroll track 30+ tier.
- [x] **IAP & Ad mediation test**: N/A — không gọi purchase SDK.

## Hiệu năng & Animation
- [x] Lazy tier rendering bằng horizontal `ListView.builder`; không có controller/ticker nội bộ.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
