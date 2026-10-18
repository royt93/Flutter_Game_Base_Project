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
- [ ] **Unit test**: Validate id/title không rỗng, id duy nhất, price label hợp lệ theo contract.
- [ ] **Widget test**: Thứ tự, badge, expired/disabled, empty state và callback đúng offerId; semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro hiển thị stack, mở offer gọi caller seam; không dùng simulator.
- [ ] **Golden test**: Một offer, nhiều offer, expired và empty trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rebuild/unmount khi mở offer không gọi callback lặp.
- [ ] **Network conditioning test**: N/A — widget presentation-only; fetch config thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau mount/unmount danh sách.
- [ ] **Frame rate / Jank test**: Scroll 20+ offers và đo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — không khởi tạo store/ad SDK.

## Hiệu năng & Animation
- [ ] Dùng `ListView.builder` cho danh sách, tránh ticker/controller per offer.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
