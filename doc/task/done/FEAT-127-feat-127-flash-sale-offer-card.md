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
- [x] **Unit test**: Validate title/price/discount 1–99/width; countdown hiển thị bằng `fmtDurLong`.
- [x] **Widget test**: Nút mua gọi `onBuyTap`; hết giờ gọi `onExpired` đúng một lần, khoá nút và hiện "Expired"; Reduced Motion không chạy sweep; semantics có đủ thông tin.
- [x] **Showcase test**: Bấm mua cập nhật trạng thái do caller sở hữu (`Flash sale buys: N`) thay vì toast.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`) theo chỉ định của người dùng (S24U offline), không dùng simulator.

## Hiệu năng & Animation
- [x] Viền neon sweep dùng `CustomPainter` trong `RepaintBoundary`; controller dừng khi hết giờ/Reduced Motion và dispose khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
