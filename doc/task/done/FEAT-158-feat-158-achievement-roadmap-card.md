---
id: FEAT-158
title: AchievementRoadmapCard — Tiến trình achievement dài hạn theo milestone
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Progression, Crafting & Collection Meta UI (Wave 14)
---

## Vì sao cần
Achievement dài hạn tạo mục tiêu xuyên nhiều session. Card roadmap cần thể hiện tiến độ, mốc kế tiếp và reward claimable rõ ràng mà vẫn để `AchievementService` và quyền cấp thưởng ở caller.

## Đề xuất phạm vi
Widget `AchievementRoadmapCard` hiển thị:
- Tên/mô tả achievement, icon/rarity, progress hiện tại/mục tiêu và các milestone caller cung cấp.
- Trạng thái locked/in-progress/claimable/claimed theo props; claim gọi `onClaim(milestoneId)`.
- Optional action xem achievement gọi `onOpen`; list dài dùng lazy rendering.
- Presentation-only: widget không đăng ký achievement, tính progress hay cấp reward.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate IDs duy nhất, progress không âm, goal dương, milestone thresholds tăng đơn điệu.
- [ ] **Widget test**: Progress, milestone states, claim/open callbacks, completed/max state, empty/loading, semantics và Reduced Motion.
- [ ] **Integration test (Device)**: CHƯA CHẠY — Pixel foreground đang là AdMob Wrapper; không gián đoạn app đang mở. Device smoke spec sẵn trong `app_boot_test.dart`; host showcase test xác nhận open/claim callbacks.
- [ ] **Golden test**: 0%, mid, completed, nhiều milestones trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rebuild/unmount khi progress animation chạy không leak ticker hoặc claim lặp.
- [ ] **Network conditioning test**: N/A — service/remote achievement sync thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau scroll/mount/unmount roadmap dài.
- [ ] **Frame rate / Jank test**: Scroll nhiều milestones, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — reward claim caller-owned.

## Hiệu năng & Animation
- [ ] List milestones render lazy; progress transition ngắn và tuân Reduced Motion.
- [ ] Sustained 60 FPS benchmark: chỉ ghi khi đo thật trên thiết bị vật lý.
