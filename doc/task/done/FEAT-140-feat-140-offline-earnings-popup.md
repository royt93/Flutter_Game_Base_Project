---
id: FEAT-140
title: OfflineEarningsPopup — Popup nhận xu tích lũy khi quay lại game
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention, Monetization & Meta-Game UI (Wave 10)
---

## Vì sao cần
Game idle/tycoon và casual có sản xuất tài nguyên nền cần chào đón người chơi quay lại bằng tổng xu tích lũy trong lúc offline. Một popup rõ số xu, thời gian offline và nút nhận thưởng làm nổi bật tiến trình mà không ép game kit tự gọi IAP hay ads.

## Đề xuất phạm vi
Widget `OfflineEarningsPopup` hiển thị:
- Tiêu đề quay lại, số xu tích lũy (`amount`), thời gian offline (`elapsed`) và tốc độ sản xuất caller cung cấp.
- Số lớn đếm lên (counter animation) từ 0 tới tổng nhận; `Reduced Motion` hiển thị kết quả cuối ngay.
- Nút `Collect` gọi `onCollect`; tùy chọn nút `Double` chỉ gọi seam callback `onDoubleTap` do caller cung cấp (caller tự mở ad/IAP, widget không chứa SDK).
- Static helper `.show(context, ...)` hiển thị qua `NeonDialog.show` in-tree/Flame-safe.
- Caller tích hợp `OfflineProgressionService.claim(productionRatePerSecond)` và cập nhật ví sau khi callback; widget không truy cập service.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate amount/rate/duration không âm; kiểm tra định dạng thời gian offline và clamp amount theo display range nếu có.
- [x] **Widget test**: Hiển thị amount/time/rate; Collect gọi đúng callback; Double callback chỉ xuất hiện khi có `onDoubleTap`; Reduced Motion tắt count-up; semantics đọc số xu và thời gian.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) mở popup, collect callback cập nhật số dư showcase; không dùng simulator. Kết quả: All tests passed! (07:13).
- [x] **Golden test**: `runGoldenMatrix` baseline/dark/vi/RTL/textScale/reducedMotion trong `test/widget/goldens/offline_earnings_popup_golden_test.dart`.
- [x] **Interruption test**: Pause/resume hoặc đóng overlay giữa count-up; không gọi callback hai lần và không phát sinh ticker orphan.
- [x] **Network conditioning test**: N/A với widget thuần presentation. Consumer integration test chỉ áp dụng nếu caller nối claim tới backend.
- [x] **Memory leak & profiling test**: MemoryWatchdog/resource lifecycle check cho controller/overlay sau dismiss.
- [x] **Frame rate / Jank test**: Pixel 7 Pro profile qua `flutter drive --profile` (`example/integration_test/offline_earnings_perf_test.dart`, 2026-10-18): 30 chu kỳ mount/count-up 1s/unmount, 4.004 frames, totalSpan p50/p95/p99 = 6.413/10.018/13.487ms, max(build,raster) p50/p95/p99 = 3.270/4.844/7.920ms, slow-frame 0,25%, jank 10 với ngưỡng max(build,raster) > 16.667ms. Đây là engine FrameTiming, không phải số missed-vsync từ compositor. RSS sau unmount (mỗi 6 chu kỳ): 289.603.584 → 293.347.328 byte, chỉ là số tham khảo, không chứng minh không leak.
- [x] **IAP & Ad mediation test**: N/A trong package; `onDoubleTap` chỉ là seam, không khởi tạo ad/IAP SDK.

## Hiệu năng & Animation
- [x] Count-up controller chỉ sống khi popup mounted, hủy khi dismiss; `RepaintBoundary` cô lập phần số lớn.
- [x] Benchmark đã đo trên Pixel 7 Pro: 10/4.004 frames vượt budget 60Hz, p99 engine frame latency 13.487ms. Không đạt zero-jank tuyệt đối; chưa đo thiết bị yếu hoặc thermal soak, không cam kết 60 FPS cho các trường hợp đó.

## Chạy lại benchmark
```bash
cd example
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/offline_earnings_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
