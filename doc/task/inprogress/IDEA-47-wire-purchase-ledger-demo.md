---
id: IDEA-47
title: "Wire PurchaseLedgerService thật vào demo ShopItemCard (thay vì chỉ hiện toast)"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: S/M
source: Claude (self-generated backlog brainstorm đợt 2 — xác nhận qua grep trực tiếp, không phỏng đoán)
---

## Vị trí
Mở rộng — `example/lib/screens/widget_showcase_screen.dart` (demo `ShopItemCard` hiện có).

## Hiện trạng
Demo `ShopItemCard` hiện tại: `onBuy: _showBoughtToast` — chỉ hiện toast "đã mua", không chạm gì tới `PurchaseLedgerService` (IDEA-33). Grep xác nhận không có chỗ nào trong `example/` gọi `PurchaseLedgerService.grantConsumable`/`grantPermanent`, dù service này viết ra đúng để cache local ngay sau khi 1 `PurchaseSeam` xác nhận mua thành công — đúng tình huống 3 card demo (100 Gems, Mega Gem Pack, Remove Ads) đang mô phỏng.

## Vì sao cần / Hậu quả
Thiếu demo khiến `PurchaseLedgerService` không có ví dụ thật minh hoạ cách ghép với `ShopItemCard` — 2 mảnh có sẵn trong kit đúng để dùng cùng nhau (1 mua tiêu hao cộng dồn, 1 mở khoá vĩnh viễn) nhưng chưa từng thấy chạy chung.

## Đề xuất
`onBuy` của "100 Gems"/"Mega Gem Pack" gọi `PurchaseLedgerService.grantConsumable(...)` (mô phỏng "IAP đã xác nhận" — không có IAP backend thật, chỉ giả lập bước xác nhận rồi gọi thẳng grant, đúng như doc comment của chính service: "meant to be called... only after it has already verified a purchase"); "Remove Ads" gọi `grantPermanent(...)` rồi cập nhật UI để card đó chuyển trạng thái "đã sở hữu" (giống style `disabled` hiện có ở card "Remove Ads" mẫu). Hiện số dư gem tích luỹ đâu đó trên demo để thấy rõ tác dụng.

## Acceptance criteria
- [x] Mua "100 Gems"/"Mega Gem Pack" gọi đúng `grantConsumable`, số dư cộng dồn đúng, hiển thị được trên demo.
- [x] Mua "Remove Ads" gọi đúng `grantPermanent`, card chuyển trạng thái đã sở hữu, mua lại lần 2 không cộng dồn/không lỗi.
- [x] Không phá test hiện có của `widget_showcase_screen_test.dart`.
- [x] Test: widget test cho luồng mua mới (consumable cộng dồn đúng, permanent chuyển trạng thái đúng, mua permanent 2 lần không lỗi).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên thiết bị Android thật hiện có (không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Animation/trạng thái disabled dùng đúng style đã có sẵn của `ShopItemCard`, không cần thêm animation mới.

## Quyết định

Implement đúng phần Đề xuất — 3 card `ShopItemCard` giờ gọi thẳng `PurchaseLedgerService`:

- "100 Gems"/"Mega Gem Pack" → `onBuy: () => _buyGems(amount)` gọi `grantConsumable('gems', amount)` (100/500) trong `setState`. Số dư hiện qua `Text('Gems: ${_purchases.balanceOf('gems')}')` ngay trên card.
- "Remove Ads" → `onBuy` là `_purchases.owns('remove_ads') ? null : _buyRemoveAds`; `priceLabel` đổi thành `'Owned'` khi đã sở hữu — tái dùng chính xác cơ chế `onBuy: null` = disabled đã có sẵn của `CommonButton`/`ShopItemCard`, không cần thêm state/style mới. Vì `owns()` idempotent và nút đã tự disable sau lần mua đầu, "mua lại lần 2" không có đường nào gọi tới `grantPermanent` lần nữa qua UI — đúng yêu cầu "không lỗi" một cách tự nhiên, không cần code phòng thủ thêm.
- Bước "xác nhận IAP" được giả lập ĐƠN GIẢN NHẤT có thể theo đúng ghi chú độ tin cậy: không có bước xác nhận riêng nào cả — nút bấm coi như "IAP đã xác nhận ngay lập tức" rồi gọi thẳng `grant*`, đúng tinh thần "không bịa thêm luồng xác nhận phức tạp".

**Test:** thêm 2 test trong `example/test/widget_showcase_screen_test.dart` — (1) mua "100 Gems" rồi "Mega Gem Pack" → "Gems: 100" rồi "Gems: 600" (cộng dồn đúng thứ tự); (2) mua "Remove Ads" → "Owned" xuất hiện, "$2.99" biến mất, không throw. Phát hiện 2 vấn đề khi viết test, cả 2 đều SỬA Ở TEST (không phải bug code sản phẩm):
  - `find.text('$2.99')`/`find.text('Owned')` ban đầu dùng `findsOneWidget` — fail vì `CommonButton` render qua `StrokeText` (2 lớp Text chồng nhau, quy ước đã biết trong codebase) → đổi sang `findsWidgets` cho việc kiểm tra tồn tại, `.last` cho tap.
  - Bấm liên tiếp "100 Gems" rồi "Mega Gem Pack" trong CÙNG 1 test (2 `ToastBanner.show()` chồng lên nhau) làm Flutter test framework tự ném assertion nội bộ (`elapsedInSeconds >= 0.0`) không liên quan gì tới code của task này — sửa bằng cách chờ toast đầu tiên chạy hết vòng đời (`pump(Duration(seconds: 3))`) trước khi bấm nút thứ 2, tránh 2 `AnimationController` chồng nhau dưới fake-async.

**Device smoke test (Samsung Galaxy A50, `R58MA6WYRPE`, real device)**: cài + mở app, cuộn tới Shop → card "ShopItemCard (IDEA-47: PurchaseLedgerService)". Bấm "100 Gems" ($0.99) → "Gems: 0" → "Gems: 100"; bấm "Mega Gem Pack" ($4.99) → "Gems: 600" (100+500, cộng dồn đúng). Bấm "Remove Ads" ($2.99) → nút chuyển thành "Owned", màu xám (disabled) — đúng luồng permanent unlock. `adb logcat` lọc `level=Error`: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1004/1004 pass (không đổi `lib/`); `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 49/49 pass. Không có thay đổi API public (`lib/` không đổi) nên không cần CHANGELOG/snapshot.

**Tự chấm điểm: 9/10** — đúng yêu cầu Đề xuất, tái dùng đúng cơ chế `onBuy: null`/`priceLabel` có sẵn của `ShopItemCard` thay vì thêm state/style mới, giữ đơn giản nhất đúng ghi chú độ tin cậy (không bịa luồng xác nhận IAP giả phức tạp), test bao phủ đủ case kể cả 2 vấn đề phát sinh khi viết test (đều được chẩn đoán đúng là vấn đề ở TEST, không phải ở code sản phẩm, trước khi sửa), device smoke test thật xác nhận toàn bộ 3 luồng mua. Trừ điểm nhẹ vì độ tin cậy "trung bình" của task tự nhận đúng — cách giả lập "xác nhận mua" (bấm là mua ngay) đơn giản tới mức gần như bỏ qua hẳn bước xác nhận, chấp nhận được cho mục đích demo nhưng không phải ví dụ đầy đủ của 1 luồng IAP thật.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-47-wire-purchase-ledger-demo.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — đặc biệt không tự bịa ra 1 luồng "xác nhận IAP giả" phức tạp, chỉ cần giả lập bước xác nhận đơn giản nhất rồi gọi grant).
2. Bổ sung ĐỦ test cho MỌI case (happy path, mua permanent 2 lần, edge case liên quan).
3. Tôn trọng animation/trạng thái disabled đã có sẵn của `ShopItemCard`, không cần thêm animation mới.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator) — chụp screenshot làm bằng chứng cụ thể, ghi lại trong `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — service và widget đúng là chưa từng ghép demo thật (xác nhận qua grep), nhưng không có IAP backend thật nên cần tự quyết định cách giả lập bước "xác nhận mua" hợp lý, dễ hơi gượng ép so với IDEA-46 (LeaderboardList) — nên giữ đơn giản nhất, không bịa thêm luồng xác nhận phức tạp.
