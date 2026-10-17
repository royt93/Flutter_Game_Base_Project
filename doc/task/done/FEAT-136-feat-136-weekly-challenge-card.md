---
id: FEAT-136
title: WeeklyChallengeCard — Card tiến độ thử thách tuần kèm đếm ngược và mốc quà
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Live-Ops Expansion (Wave 9)
---

## Vì sao cần
Cơ chế thử thách hàng tuần (Weekly Challenge / Weekly Race) đưa ra chuỗi mục tiêu kéo dài 7 ngày với phần thưởng tích lũy theo từng mốc. Người chơi cần theo dõi tiến độ tổng thể, thời gian còn lại đến khi tuần kết thúc và nhận quà từng mốc mà không cần rời màn hình chính.

## Đề xuất phạm vi
Widget `WeeklyChallengeCard` hiển thị:
- Tiêu đề thử thách, mô tả ngắn gọn, icon/hình minh họa theo chủ đề tuần.
- Đếm ngược thời gian còn lại đến hết tuần dùng `fmtDurDays` (chuyển sang ngày/giờ khi > 24h).
- Thanh tiến độ tích lũy (`currentProgress`, `targetProgress`) kèm các mốc nhận thưởng nhỏ (1-3 mốc).
- Khi hết tuần: khóa thao tác, đổi trạng thái sang "Expired" / "Ended", gọi `onExpired` đúng một lần.
- Nút hoặc tap vào card gọi callback `onTap` hoặc `onClaimMilestone(index)` do caller sở hữu.
- Widget thuần dữ liệu: caller sở hữu tiến trình và logic trả thưởng qua `RewardTransactionPipeline`.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Kiểm tra `currentProgress/targetProgress` progress fraction, validate target/progress/dimensions, milestones 1-3 với target tăng dần và không vượt target.
- [x] **Widget test**: Tiêu đề, thanh tiến độ và milestones; tap card/claim callback; milestone khoá trước target, mở sau target, không claim lặp khi `isClaimed`; hết giờ gọi `onExpired` một lần, giữ card và khoá hành động; Reduced Motion tắt fill animation; semantics active/ended.
- [x] **Integration test (Device)**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), tap cộng tiến độ/claim và xác nhận trạng thái.
- [x] **Golden test**: `runGoldenMatrix` baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion; không overflow hoặc vi phạm golden-matrix guidelines trong các case.
- [x] **Interruption test**: Widget test dispatch lifecycle paused/resumed; countdown còn mounted, không crash/expire nhầm.
- [x] **Network conditioning test**: N/A — widget presentation-only, không gọi network.
- [x] **Memory leak & profiling test**: Unmount khi timer đang chạy, pump qua expiry và xác nhận `onExpired` không bị gọi sau dispose; không sở hữu AnimationController/StreamSubscription. MemoryWatchdog infrastructure test pass.
- [x] **Frame rate / Jank test**: Profile workload 4 chu kỳ trên Pixel 7 Pro (81 frames): p50=19.00ms, p95=73.98ms, p99=179.05ms, slow=61.7% (50), jank=13. Đây là workload hỗn hợp Wave 8, không phải đo riêng WeeklyChallengeCard; không tuyên bố 60 FPS.
- [x] **IAP & Ad mediation test**: N/A — widget không khởi tạo IAP/ads; caller owns any purchase/ad route.

## Hiệu năng & Animation
- [x] Progress bar dùng AnimatedContainer với Reduced Motion support; mỗi giây chỉ card countdown cập nhật, timer dừng và dispose khi expired/unmount.
- [ ] Sustained 60 FPS benchmark riêng cho WeeklyChallengeCard: chưa đo, không tuyên bố đạt 60 FPS.
