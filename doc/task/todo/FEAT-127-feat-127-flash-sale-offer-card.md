---
id: FEAT-127
title: FlashSaleOfferCard — Thẻ ưu đãi giờ vàng đếm ngược kèm tia chớp neon
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Các gói ưu đãi có hạn giờ (Flash Sale / Starter Pack) với đồng hồ đếm ngược gấp gáp và badge giảm giá sâu (-70%, -80%) là công cụ chuyển đổi IAP hiệu quả nhất trong game casual.

## Đề xuất phạm vi
Widget `FlashSaleOfferCard` hiển thị thẻ gói quà kèm badge giảm giá, vệt sáng tia chớp neon chạy quanh viền thẻ hoặc góc thẻ, đồng hồ đếm ngược giờ vàng và nút mua caller-owned.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra tính toán % giảm giá, format đồng hồ đếm ngược và validate dữ liệu gói ưu đãi.
- [ ] **Widget test**: Kiểm tra bấm nút mua gọi callback `onBuyTap`, khi hết giờ đếm ngược gọi `onExpired` và chuyển trạng thái; Reduced Motion dừng tia chớp chạy viền.
- [ ] **Showcase test**: Tích hợp thẻ ưu đãi vào showcase, bấm mua hiển thị toast xác nhận.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap trên thiết bị thật TECNO KJ7 / physical device, không dùng simulator.

## Hiệu năng & Animation
- [ ] Vệt sáng viền neon chạy bằng shader / custom painter có `RepaintBoundary`, tự hủy animation khi unmount hoặc hết giờ.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
