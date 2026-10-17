---
id: FEAT-137
title: WinStreakFlameHud — HUD chuỗi thắng với hệ số nhân thưởng và hiệu ứng lửa
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Live-Ops Expansion (Wave 9)
---

## Vì sao cần
Chuỗi thắng liên tiếp (Win Streak) tạo động lực chơi thêm một màn nữa để giữ hệ số nhân thưởng. Người chơi cần thấy rõ số trận thắng liên tiếp và phần thưởng sẽ mất nếu thua; mức lửa tăng dần theo chuỗi làm tiến trình dễ nhận biết và mang tính ăn mừng.

## Đề xuất phạm vi
Widget `WinStreakFlameHud` hiển thị:
- Số trận thắng liên tiếp (`streakCount`) cùng hệ số nhân caller cung cấp (`rewardMultiplier`).
- Cấp lửa theo các ngưỡng caller cung cấp hoặc theo `streakCount` (tối đa 3 cấp: cyan/lime/gold hoặc orange).
- Flame icon có hiệu ứng pulse nhẹ khi streak tăng; khi reset/thua, chuyển về trạng thái nền bình thường không phát animation ăn mừng.
- `Reduced Motion`: bỏ pulse, giữ biểu tượng và màu tĩnh.
- Widget thuần dữ liệu, callback tùy chọn `onInfoTap`; không tự cập nhật ledger hoặc quyết định mất/thêm phần thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Kiểm tra trạng thái/count label, ánh xạ streak sang cấp lửa/màu, validate `streakCount >= 0`, `rewardMultiplier >= 1`.
- [ ] **Widget test**: Tăng streak kích hoạt pulse; giảm/reset streak không phát pulse; Reduced Motion; callback info; semantics đọc đúng streak và multiplier.
- [ ] **Integration test (Device)**: Smoke test trên Pixel 7 Pro, cập nhật chuỗi thắng từ caller state và reset khi mô phỏng thua.
- [ ] **Golden test**: So khớp các cấp lửa trên light/dark, RTL và textScale 1.0/1.4.
- [ ] **Interruption test**: Background/resume trong lúc pulse không leak ticker hoặc tiếp tục animation ngoài ý muốn.
- [ ] **Network conditioning test**: N/A (widget thuần presentation, không gọi network).
- [ ] **Memory leak & profiling test**: Dùng MemoryLifecycleWatchdog để kiểm tra controller được dispose sau unmount và không còn orphan.
- [ ] **Frame rate / Jank test**: Đo FrameTiming khi streak tăng liên tiếp; ghi p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A (HUD không tự mua hàng hoặc hiển thị quảng cáo).

## Hiệu năng & Animation
- [ ] Một `AnimationController` cho flame pulse; chỉ mount ticker khi streak > 0 và motion được phép.
- [ ] Sustained 60 FPS benchmark: đo theo workload định sẵn nếu cần.
