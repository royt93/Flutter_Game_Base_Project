---
id: FEAT-145
title: VipPerkProgressRow — Hàng hiển thị cấp VIP và thanh tiến độ đặc quyền
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Live-Ops, Retention & VIP Meta-Game UI (Wave 11)
---

## Vì sao cần
Hệ thống loyalty/VIP cần hiển thị rõ ràng cấp hiện tại, tiến độ điểm tới cấp kế tiếp và danh sách quyền lợi mở khóa. Người chơi cần biết họ đang ở đâu trong hệ thống VIP để tạo động lực nạp hoặc tham gia sự kiện.

## Đề xuất phạm vi
Widget `VipPerkProgressRow` hiển thị:
- Cấp VIP hiện tại (`currentTier`, `tierLabel`), điểm hiện tại và điểm cần để lên cấp kế tiếp (`currentPoints`, `nextTierPoints`).
- Thanh tiến độ bo cong với phần trăm hoàn thành; badge cấp độ nổi bật.
- Danh sách ngắn các đặc quyền caller cung cấp (`VipPerk`: icon, label, isUnlocked).
- Nút `View Perks` hoặc `Upgrade` gọi `onAction` tùy chọn; widget không tự xử lý IAP hay thăng cấp.
- Presentation-only: caller quản lý điểm VIP và cấp VIP.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate points không âm, currentTier >= 0, nextTierPoints > 0, points <= nextTierPoints (hoặc clamp 100% khi max level) (`vip_perk_progress_row_test.dart`, 10 test pass).
- [x] **Widget test**: Hiển thị tier/points/progress/perks; onAction gọi đúng; max tier hiển thị "MAX"; semantics đọc cấp độ và tiến độ; Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) kiểm tra tăng điểm, thăng tier và action callback qua showcase thật; không dùng simulator.
- [x] **Golden test**: Ma trận normal/max tier trên light/dark/vi/RTL/textScale/reducedMotion (`vip_perk_progress_row_golden_test.dart`).
- [x] **Interruption test**: Rebuild hoặc unmount giữa lúc thanh tiến độ animate không gây leak ticker.
- [x] **Network conditioning test**: N/A — widget thuần presentation.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-145.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming (p50/p95/p99, slow-frame %, jank count).
- [x] **IAP & Ad mediation test**: N/A — perk row không tự gọi store SDK.

## Hiệu năng & Animation
- [x] Thanh progress animated ngắn (500ms) bằng `TweenAnimationBuilder` có `RepaintBoundary` cô lập; Reduced Motion đặt `Duration.zero`.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
