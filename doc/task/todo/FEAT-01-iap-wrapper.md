---
id: FEAT-01
title: IAP wrapper tối giản (in_app_purchase)
type: feature
priority: P0
effort: L
source: fork nội bộ + agy, đối chiếu: chưa có gì trong lib/ hiện tại (grep xác nhận không có IAP)
---

## Vì sao cần
Casual/idle game gần như luôn cần bán vật phẩm/gỡ quảng cáo/gói VIP. Package
hiện tại (`storage`, `i18n`, `audio`, `haptics`, `reminder`, `theme`, `share`,
widget kit) hoàn toàn chưa có gì cho monetization qua IAP.

## Đề xuất phạm vi (MVP cho 1 base kit — không phải full store)
- 1 service (`IapService extends GetxService`) bọc `in_app_purchase`: load
  product list, mua, khôi phục purchase, verify local (không cần server-side
  receipt validation ở base kit — ghi rõ giới hạn này).
- Persist trạng thái đã mua qua `StorageService` (thêm `StorageKeys` tương ứng,
  không dùng string literal theo đúng convention hiện có).
- 1 callback/stream đơn giản để app lắng nghe kết quả mua thành công/thất bại.

## Acceptance criteria
- [ ] Mua 1 sản phẩm non-consumable, tắt/mở lại app vẫn nhớ đã mua.
- [ ] Test service với mock `in_app_purchase` (không cần store thật).
