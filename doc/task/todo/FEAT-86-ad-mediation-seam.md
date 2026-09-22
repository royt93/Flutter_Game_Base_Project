---
id: FEAT-86
title: "AdMediationSeam — seam trung lập cho rewarded/interstitial ad, mirror thiết kế PurchaseSeam"
type: feature
priority: P1
effort: M
source: "Fork nội bộ (brainstorm task/tính năng mới + tính năng độc quyền), đối chiếu ls lib/core/*.dart xác nhận chưa có seam tương tự"
---

## Vị trí
File mới `lib/core/ad_mediation_seam.dart`, đối chiếu `lib/core/purchase_seam.dart` (pattern mirror).

## Hiện trạng
Kit đã có seam platform-neutral cho IAP (`PurchaseSeam` — không có `Noop*` default, cố ý để lộ rõ chưa tích hợp thật), analytics, crash reporting, cloud save, remote config — nhưng KHÔNG có seam nào cho quảng cáo (rewarded/interstitial), dù đây là 1 trụ cột doanh thu kinh điển của casual/idle game. Đã `ls lib/core/*.dart` xác nhận không có file nào tên `ad_*`/`admob_*`/tương tự.

## Vì sao cần / Hậu quả
Mọi casual/idle game thật đều cần "xem quảng cáo để x2 thưởng"/"xem quảng cáo miễn phí năng lượng" — hiện tại consumer app phải tự thiết kế toàn bộ interface này từ đầu, không có convention chuẩn từ kit dù kit đã có sẵn pattern seam rất rõ ràng cho các tích hợp platform-specific khác.

## Đề xuất
Thêm `AdMediationSeam` (interface trừu tượng): `Future<bool> isRewardedReady()`, `Future<AdResult> showRewarded()`, `Future<bool> isInterstitialReady()`, `Future<void> showInterstitial()`. KHÔNG có `Noop*` default (giống `PurchaseSeam` — cố ý để lộ rõ nếu consumer quên đăng ký seam thật). Consumer tự implement adapter cho AdMob/Unity Ads/... và `Get.put<AdMediationSeam>(myAdapter, permanent: true)`.

## Acceptance criteria
- [ ] `AdMediationSeam` là interface trừu tượng thuần, không phụ thuộc SDK quảng cáo cụ thể nào.
- [ ] Không có `Noop*` implementation mặc định (nhất quán với `PurchaseSeam`).
- [ ] `AdMediationSeam.maybe` (null-safe accessor) cho call site chưa đăng ký seam.
- [ ] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [ ] Demo trong `example/` dùng 1 fake adapter test-only minh hoạ flow gọi `showRewarded()`.
- [ ] Test unit cho interface + fake adapter, widget test cho demo.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-86-ad-mediation-seam.md` này trước khi làm. Đọc toàn bộ `lib/core/purchase_seam.dart` (pattern mirror chính xác — cùng convention không-Noop-default) và cách các seam khác được export/demo trước khi tạo file mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device Android thật khuyến khích (demo với fake adapter, verify UI phản hồi đúng) không bắt buộc nếu widget test đủ chứng minh (không có SDK quảng cáo thật để test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua `ls lib/core/*.dart` (fork nội bộ) không có seam nào cho ads, gap thật với genre-fit rõ ràng (casual/idle game). Không trùng task nào trong `doc/task/done/`.
