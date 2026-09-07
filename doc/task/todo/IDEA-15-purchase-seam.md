---
id: IDEA-15
title: "PurchaseSeam — seam trung lập cho IAP (mua/khôi phục), cùng họ với CrashReporter/AnalyticsProvider/CloudSaveProvider"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: S
source: Claude, đề xuất feature mới (round 5)
---

## Ý tưởng
Kit đã có 4 "seam trung lập" theo đúng 1 pattern: `CrashReporter`,
`AnalyticsProvider`, `CloudSaveProvider`, `RemoteConfigService` — mỗi cái là
1 abstract class, package không phụ thuộc SDK cụ thể nào, app tự implement
rồi `Get.put<X>(myAdapter, permanent: true)`. `ShopItemCard` widget đã có
(hiển thị icon/title/giá + `onTap`) nhưng bản thân widget không biết gì về
việc mua hàng thật — đúng, nhưng khác với 4 seam kia, không có 1 interface
chuẩn nào cho "mua hàng" (`buy`/`restorePurchases`/`isOwned`) để app implement
theo, dù đây cũng là nhu cầu gần như chắc chắn có ở mọi casual game có
`ShopItemCard`.

## Vì sao cần
Nhất quán với 4 seam đã có — cùng lý do, cùng effort thấp (chỉ 1 abstract
class + docs, không phụ thuộc `in_app_purchase` package thật).

## Đề xuất
`abstract class PurchaseSeam { Future<bool> buy(String productId); Future<void> restorePurchases(); bool isOwned(String productId); }`
— API tối giản nhất có thể, không cố mô hình hoá subscription/consumable
khác nhau (quá phức tạp cho 1 seam, app tự lo phần đó trong implementation
riêng).

## Acceptance criteria
- [ ] File mới `lib/core/purchase_seam.dart`, abstract class + doc comment giải thích rationale (giống 4 seam kia).
- [ ] Test tối thiểu: 1 fake implementation, xác nhận interface gọi được đúng.
- [ ] CLAUDE.md cập nhật danh sách core services (hiện đang thiếu cả `achievement_service`/`analytics_provider`/`remote_config_service`/`save_integrity`/`in_app_review_helper` — có thể gộp việc cập nhật doc này vào cùng lúc, hoặc tách task riêng).

## Ghi chú độ tin cậy
Trung bình — không chắc có đáng thêm 1 interface nữa hay không, vì
`ShopItemCard` đã decouple hoàn toàn qua `onTap` (app tự do gọi bất kỳ
API mua hàng nào bên trong `onTap`, không cần seam mới để làm việc đó).
Giá trị của seam này chủ yếu là **tính nhất quán** (1 pattern chuẩn để theo,
giống các seam khác), không phải mở khoá năng lực gì mới — cần xác nhận có
đáng làm hay là YAGNI trước khi code.
