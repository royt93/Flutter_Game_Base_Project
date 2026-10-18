---
id: FEAT-148
title: DailyOfferStack — Danh sách offer hằng ngày theo mức ưu tiên và thời hạn
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Shop, Events & Retention UI (Wave 12)
---

## Vì sao cần
Shop và live-ops thường cùng lúc có nhiều offer giới hạn thời gian. Một stack có thứ tự rõ, nhãn ưu tiên và trạng thái hết hạn giúp người chơi nhận biết offer nào còn đáng xem mà không để widget tự quyết định giao dịch.

## Đề xuất phạm vi
Widget `DailyOfferStack` hiển thị:
- Danh sách `DailyOffer` do caller truyền, với tiêu đề, mô tả ngắn, hình/icon, giá đã format, badge và thời hạn tùy chọn.
- Thứ tự danh sách giữ nguyên theo caller; không tự xếp hạng offer hoặc áp dụng luật giá.
- Offer hết hạn được đánh dấu/khóa theo props caller cung cấp; nút mở offer gọi `onOpen(offerId)`.
- Empty state khi không có offer; danh sách dài dùng lazy rendering.
- Presentation-only: caller tích hợp shop, RemoteConfig và purchase flow; widget không gọi IAP/ad SDK.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate id/title không rỗng, duplicate id và price label (`daily_offer_stack_test.dart`, 7 test pass).
- [x] **Widget test**: Thứ tự caller, badge, expired/disabled, empty state, callback đúng offerId, semantics và textScale 2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) mở active offer qua showcase caller seam, expired offer disabled; không dùng simulator.
- [x] **Golden test**: Active, mixed expired/active và empty trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: N/A — widget không quản lý stateful overlay/timer/animation.
- [x] **Network conditioning test**: N/A — widget presentation-only; fetch config thuộc caller.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-148.
- [ ] **Frame rate / Jank test**: CHƯA ĐO scroll 20+ offers trên device.
- [x] **IAP & Ad mediation test**: N/A — không khởi tạo store/ad SDK.

## Hiệu năng & Animation
- [x] Dùng `ListView.builder` cho danh sách, không có ticker/controller per offer.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.

## Showcase
- [x] Demo giữ state caller in-memory; danh sách hiển thị theo đúng thứ tự caller, `onOpen` chỉ tăng counter và không mua hàng.
