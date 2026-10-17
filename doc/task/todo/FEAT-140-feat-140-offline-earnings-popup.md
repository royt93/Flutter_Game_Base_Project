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
- [ ] **Unit test**: Validate amount/rate/duration không âm; kiểm tra định dạng thời gian offline và clamp amount theo display range nếu có.
- [ ] **Widget test**: Hiển thị amount/time/rate; Collect gọi đúng callback; Double callback chỉ xuất hiện khi có `onDoubleTap`; Reduced Motion tắt count-up; semantics đọc số xu và thời gian.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở popup, collect callback cập nhật số dư showcase; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` baseline/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Pause/resume hoặc đóng overlay giữa count-up; không gọi callback hai lần và không phát sinh ticker orphan.
- [ ] **Network conditioning test**: N/A với widget thuần presentation. Consumer integration test chỉ áp dụng nếu caller nối claim tới backend.
- [ ] **Memory leak & profiling test**: MemoryWatchdog/resource lifecycle check cho controller/overlay sau dismiss.
- [ ] **Frame rate / Jank test**: FrameTiming workload count-up + dismiss, báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A trong package; `onDoubleTap` chỉ là seam, không khởi tạo ad/IAP SDK.

## Hiệu năng & Animation
- [ ] Count-up controller chỉ sống khi popup mounted, hủy khi dismiss; `RepaintBoundary` cô lập phần số lớn.
- [ ] Sustained 60 FPS benchmark: đo theo workload định sẵn nếu cần.
