---
id: FEAT-151
title: ComebackBundleCard — Thẻ quà quay lại với phần thưởng theo caller
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Shop, Events & Retention UI (Wave 12)
---

## Vì sao cần
Sau thời gian vắng mặt, người chơi có thể nhận ưu đãi/quà chào mừng quay lại. Thẻ cần làm rõ điều kiện, nội dung gói và hạn nhận, trong khi eligibility và quyền lợi vẫn do game quyết định.

## Đề xuất phạm vi
Widget `ComebackBundleCard` hiển thị:
- Tiêu đề, mô tả thời gian vắng mặt caller format sẵn, danh sách phần thưởng và badge ưu đãi.
- Hạn nhận/expired theo trạng thái caller truyền; widget không tự xác định người chơi đủ điều kiện.
- Action `Claim` hoặc `View Offer` gọi callback caller cung cấp; không tự cấp quà, mua hàng hoặc mở ad.
- Empty/disabled state khi offer không còn khả dụng.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate title/body/absence/action labels và reward labels/amounts (`comeback_bundle_card_test.dart`, 5 tests pass).
- [x] **Widget test**: Hiển thị rewards/expiry; Claim/View callback tách biệt; expired khóa actions; semantics; textScale 2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) kiểm tra view/claim callback và expired-disabled state qua showcase thật; pass.
- [x] **Golden test**: Active/expired có rewards trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: N/A — không có timer/controller nội bộ.
- [x] **Network conditioning test**: N/A — eligibility/fetch thuộc caller.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-151.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming.
- [x] **IAP & Ad mediation test**: N/A — action chỉ là seam; không khởi tạo store/ad SDK trong widget.

## Hiệu năng & Animation
- [x] Presentation-only layout, không có animation/timer nội bộ.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.

## Quyết định API
- [x] Tái dùng `MilestoneReward`; expiry state/label do caller cung cấp, không có countdown timer nội bộ.
