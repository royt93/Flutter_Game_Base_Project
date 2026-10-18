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
- [ ] **Unit test**: Validate title/body, reward amounts và labels không rỗng/âm.
- [ ] **Widget test**: Hiển thị rewards, expiry, disabled state, callbacks, semantics và Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở/nhận offer qua caller seam; không dùng simulator.
- [ ] **Golden test**: Active/expired, ít/nhiều rewards, discount badge trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Dismiss hoặc background giữa entrance không gọi claim hai lần.
- [ ] **Network conditioning test**: N/A — eligibility/fetch thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau mount/dismiss.
- [ ] **Frame rate / Jank test**: FrameTiming entrance và claim/dismiss, báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A nếu action chỉ là seam; không khởi tạo store/ad SDK trong widget.

## Hiệu năng & Animation
- [ ] Presentation-only layout; mọi animation tuân Reduced Motion.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
