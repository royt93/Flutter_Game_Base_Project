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
- [x] **Unit test**: `winStreakFlameColor` maps đúng 3 bậc màu (0: muted, 1: cyan, 2-4: gold, 5+: orange); validate `streakCount >= 0`, `height > 0`, `width > 0`.
- [x] **Widget test**: Tăng streak kích hoạt celebration pop scale trên multiplier badge và settle về 1.0; giảm/reset streak không phát pop; Reduced Motion; callback onInfoTap; app interruption (paused/resumed) an toàn; semantics đọc đúng streak và multiplier.
- [x] **Integration test (Device)**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), tăng streak và reset streak khi mô phỏng thua.
- [x] **Golden test**: `runGoldenMatrix` sweep 7 dimensions (baseline, dark, locale-vi, RTL, textScale 1.3/2.0, reducedMotion) không overflow.
- [x] **Interruption test**: Lifecycle paused/resumed dispatch không gây leak ticker hay crash.
- [x] **Network conditioning test**: N/A — widget thuần presentation, không gọi network.
- [x] **Memory leak & profiling test**: Hai AnimationController (`_breatheController`, `_popController`) dispose sạch khi unmount; không tạo orphan resource.
- [x] **Frame rate / Jank test**: Đo benchmark telemetry trên Pixel 7 Pro cùng các widget Wave 8: p50=19.00ms, p95=73.98ms, p99=179.05ms, slow=61.7% (50), jank=13. Đây là workload hỗn hợp, không phải đo riêng WinStreakFlameHud; không tuyên bố 60 FPS.
- [x] **IAP & Ad mediation test**: N/A — HUD thuần hiển thị chuỗi thắng, không tự mua hàng hoặc chạy ad.

## Hiệu năng & Animation
- [x] Tách riêng breathing pulse cho icon và celebration pop cho badge; chỉ lặp khi `streakCount > 0` và Reduced Motion tắt; bọc `RepaintBoundary`.
- [ ] Sustained 60 FPS benchmark riêng cho WinStreakFlameHud: chưa đo, không tuyên bố đạt 60 FPS.
