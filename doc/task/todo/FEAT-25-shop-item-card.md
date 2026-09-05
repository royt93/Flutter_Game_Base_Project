---
id: FEAT-25
title: ShopItemCard — card sẵn cho lưới shop/IAP
type: feature
priority: P1
effort: S
source: user pick (vòng đề xuất thêm widget, chốt)
---

## Vì sao cần
Nối thẳng FEAT-01 (IAP wrapper) — khi có sản phẩm để bán, cần 1 card chuẩn
hiển thị icon/tên/giá + nút mua thay vì mỗi app tự ghép lại từ `PanelCard` +
`CommonButton` + `CurrencyCounter` + `RibbonBadge` (FEAT-20) mỗi lần.

## Đề xuất phạm vi
`ShopItemCard`: bọc `PanelCard` có sẵn, nhận `icon`/`title`/`priceLabel`
(string, không tự format tiền tệ — để app quyết định `$0.99` hay theo giá
IAP thật), `onBuy` callback, `ribbon` tuỳ chọn (`RibbonBadge` con). Thuần
trình bày, không tự gọi `in_app_purchase` (giữ đúng ranh giới: widget UI vs
FEAT-01 service logic).

## Yêu cầu test
- **Unit test**: không áp dụng (thuần trình bày, không có logic tính toán).
- **Widget test**: dựng với đủ tổ hợp có/không `ribbon`, tap `onBuy` gọi đúng callback; golden test cho layout cơ bản.
- **Integration test**: dựng 1 lưới `GridView` nhiều `ShopItemCard` trong `example/integration_test/`, verify scroll + tap đúng item trên thiết bị thật.

## Demo
Section "Shop Card" trong `WidgetShowcaseScreen`, 3-4 card mẫu (có/không ribbon).

## Acceptance criteria
- [ ] Card dùng lại đúng `PanelCard`/`CommonButton`/`RibbonBadge` có sẵn, không viết lại style riêng.
- [ ] Đủ 3 loại test + demo.
