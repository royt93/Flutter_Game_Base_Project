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
- [ ] **Unit test**: Kiểm tra tính toán % tiến độ, mốc hoàn thành, validate `targetProgress > 0`, `currentProgress >= 0`, chuỗi đếm ngược theo ngày/giờ.
- [ ] **Widget test**: Hiển thị tiêu đề, thanh tiến độ, các mốc quà; tap card gọi `onTap`; tap mốc quà gọi `onClaimMilestone`; hết giờ gọi `onExpired` một lần và khóa tương tác; Reduced Motion tắt animation fill mượt; semantics đọc rõ tiến độ và thời gian còn lại.
- [ ] **Integration test (Device)**: Smoke test trên thiết bị vật lý thật (Pixel 7 Pro), tap nhận thưởng và cập nhật trạng thái UI.
- [ ] **Golden test**: So khớp pixel trên ma trận giao diện (light/dark, RTL, textScale 1.0/1.4).
- [ ] **Interruption test**: Đổi trạng thái vòng đời app (paused/resumed qua RoyLifecycleCoordinator), timer đếm ngược không bị lệch hoặc crash.
- [ ] **Network conditioning test**: N/A (widget thuần presentation; không gọi network trực tiếp).
- [ ] **Memory leak & profiling test**: Kiểm tra không có AnimationController hoặc Timer bị bỏ sót (orphan) sau khi unmount qua MemoryLifecycleWatchdog.
- [ ] **Frame rate / Jank test**: Đo FrameTiming (p50/p95/p99) dưới workload cập nhật tiến độ; ghi nhận telemetry thực tế, không tuyên bố 60 FPS nếu chưa đạt.
- [ ] **IAP & Ad mediation test**: N/A (không trực tiếp trigger in-app purchase hoặc show ad; nếu có nút dẫn tới shop thì caller xử lý).

## Hiệu năng & Animation
- [ ] Thanh tiến độ và đếm ngược nằm trong `RepaintBoundary`, giải phóng `Timer` và `AnimationController` khi unmount.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
