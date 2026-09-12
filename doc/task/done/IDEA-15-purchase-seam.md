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
- [x] File mới `lib/core/purchase_seam.dart`, abstract class + doc comment giải thích rationale (giống 4 seam kia).
- [x] Test tối thiểu: 1 fake implementation, xác nhận interface gọi được đúng.
- [x] CLAUDE.md cập nhật danh sách core services (hiện đang thiếu cả `achievement_service`/`analytics_provider`/`remote_config_service`/`save_integrity`/`in_app_review_helper` — có thể gộp việc cập nhật doc này vào cùng lúc, hoặc tách task riêng).

## Ghi chú độ tin cậy
Trung bình — không chắc có đáng thêm 1 interface nữa hay không, vì
`ShopItemCard` đã decouple hoàn toàn qua `onTap` (app tự do gọi bất kỳ
API mua hàng nào bên trong `onTap`, không cần seam mới để làm việc đó).
Giá trị của seam này chủ yếu là **tính nhất quán** (1 pattern chuẩn để theo,
giống các seam khác), không phải mở khoá năng lực gì mới — cần xác nhận có
đáng làm hay là YAGNI trước khi code.

## Quyết định
Xác nhận không phải YAGNI — nhất quán với 4 seam hiện có đủ lý do để làm
(cùng effort thấp, cùng pattern, không khoá app vào bất kỳ IAP SDK nào).
Làm đúng như đề xuất, không mở rộng thêm: `abstract class PurchaseSeam`
với đúng 3 method `buy(String productId)`/`restorePurchases()`/
`isOwned(String productId)`, cộng `static PurchaseSeam? get maybe` (mirror
`CrashReporter.maybe`).

Quyết định KHÔNG thêm `NoopPurchaseSeam` default (khác `AnalyticsProvider`
— seam duy nhất trong kit có Noop default): ghi rõ lý do trong doc comment
— im lặng no-op 1 lần bấm mua hàng sẽ che giấu 1 lỗi tích hợp thật (app
quên đăng ký adapter), khác hẳn analytics event bị mất (vô hại). 3/4 seam
còn lại (`CrashReporter`/`CloudSaveProvider`/`RemoteConfigService`) cũng
không có Noop default, nên đây là đa số, không phải ngoại lệ.

Ghi chú "CLAUDE.md thiếu achievement_service/analytics_provider/..." trong
acceptance criteria đã LỖI THỜI — kiểm tra lại thấy tất cả 5 file đó đã
được liệt kê đầy đủ trong CLAUDE.md từ ENH-21 (commit `6ff2111`, trước
round audit UI/animation này). Chỉ cần thêm 1 dòng cho `purchase_seam.dart`
vào bullet "Seams" hiện có.

Test: 4 test mới (`test/core/purchase_seam_test.dart`) — `maybe` null khi
chưa đăng ký, `maybe` trả đúng instance, `buy()` cập nhật `isOwned()` đúng
theo từng `productId`, `restorePurchases()` gọi được qua interface.
`flutter analyze` sạch cả root + `example/`. `flutter test
--exclude-tags slow`: tất cả pass, không regression (495→499).

Không có device smoke test — đây là seam thuần Dart (`abstract class`,
không render UI, không widget nào dùng trực tiếp), giống các seam khác
trong kit (`CrashReporter`/`AnalyticsProvider`/`RemoteConfigService`) cũng
không cần smoke test trên thiết bị thật khi được thêm.
