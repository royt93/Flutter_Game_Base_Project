---
id: ENH-66
title: "ShopItemCard: chưa expose CommonButton.loading (IDEA-53) — đúng ví dụ động lực của chính IDEA-53"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog audit — đọc trực tiếp `lib/presentation/widgets/common/shop_item_card.dart` và `doc/task/done/IDEA-53-common-button-loading-state.md`)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/shop_item_card.dart` (`ShopItemCard`).

## Hiện trạng
`IDEA-53` (đã done) thêm `loading: bool` vào `CommonButton` — chính task đó lấy `ShopItemCard`'s nút "Buy" làm VÍ DỤ ĐỘNG LỰC CHÍNH trong `## Hiện trạng`: *"`ShopItemCard`'s nút 'Buy' (bọc `CommonButton`) là ví dụ rõ nhất khác đang thiếu: bấm mua xong, nếu `onBuy` là 1 hành động async... thiếu cách chặn double-tap ở tầng UI trong lúc chờ async"*. Nhưng đọc lại `shop_item_card.dart` sau khi IDEA-53 đã xong: `ShopItemCard` KHÔNG có field `loading` nào, và `CommonButton` bên trong (dòng 91-97) không truyền `loading:` — nghĩa là khả năng mới thêm ở `CommonButton` chưa hề được nối tới đúng widget đã tạo ra nhu cầu ban đầu.

## Vì sao cần / Hậu quả
1 consumer app muốn hiện spinner trên nút "Buy" trong lúc chờ `in_app_purchase` xử lý (đúng kịch bản IAP thật — gọi store, chờ callback, có thể mất vài giây) phải tự bọc lại `ShopItemCard` bằng widget riêng hoặc tự dựng lại cả `PanelCard`+`CommonButton` từ đầu chỉ để thêm được `loading:` — mất hết lợi ích "ready-made" mà `ShopItemCard` hứa hẹn trong chính doc comment của nó ("rather than every app re-assembling those by hand").

## Đề xuất
Thêm `bool loading = false` vào `ShopItemCard`, truyền thẳng xuống `CommonButton(loading: loading, ...)` — không đổi hành vi mặc định (`loading: false` giữ nguyên y hệt hiện tại).

## Acceptance criteria
- [x] `ShopItemCard(loading: true, ...)`: `CommonButton` bên trong nhận đúng `loading: true` — hiện spinner, chặn `onBuy` (test qua hành vi `CommonButton` đã có ở IDEA-53, `ShopItemCard` chỉ cần truyền đúng tham số).
- [x] `loading: false` (mặc định): hành vi y hệt trước khi có tham số này — không phá bất kỳ test/call site nào đang dùng `ShopItemCard`.
- [x] `MergeSemantics` (ENH-44) vẫn hoạt động đúng khi `loading: true` — label merged vẫn phản ánh đúng trạng thái loading (kế thừa từ `CommonButton`'s tự xử lý label, `ShopItemCard` không cần tự làm gì thêm cho phần này).
- [x] Test: unit/widget test đầy đủ mọi case trên trong `test/widget/common/shop_item_card_test.dart`.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` — nếu muốn minh hoạ, cân nhắc wire vào demo `ShopItemCard` sẵn có trong `widget_showcase_screen.dart` (không bắt buộc, nếu làm phải test + device smoke test cho phần đó, giống cách IDEA-53 đã demo "Simulate async" cho `CommonButton`).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-66-shop-item-card-loading-state.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/shop_item_card.dart`, `lib/presentation/widgets/common/common_button.dart` (đã có `loading` từ IDEA-53), và `doc/task/done/IDEA-53-common-button-loading-state.md` để hiểu đúng ngữ cảnh/lý do tính năng này được thêm. Implement bằng TDD (viết test fail trước, code cho pass) — đây chỉ là truyền tiếp 1 tham số đã tồn tại, không tạo logic mới.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — chỉ 1 param bool truyền thẳng xuống `CommonButton`, không tự viết lại logic spinner/block-tap nào ở tầng `ShopItemCard`).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên wire vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó, kiểm tra `mobile_list_available_devices`/`mobile_get_foreground_app`/`ListAgents` FRESH trước khi thao tác vì thiết bị có thể chia sẻ với peer session khác).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `shop_item_card.dart` (constructor không có `loading`, `CommonButton` ở dòng 91-97 không truyền `loading:`) và đọc lại chính `doc/task/done/IDEA-53-common-button-loading-state.md`'s `## Hiện trạng`, nơi `ShopItemCard` được nêu đích danh là ví dụ động lực nhưng chưa từng được quay lại wire sau khi `CommonButton.loading` đã xong. Effort nhỏ (1 param truyền tiếp), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Thêm `bool loading = false`, truyền thẳng `CommonButton(loading: loading, ...)` — đúng 1 tham số, không tự xử lý spinner/block-tap ở tầng `ShopItemCard`.

**Test:** 4 test mới trong `test/widget/common/shop_item_card_test.dart` nhóm "ENH-66" — truyền đúng xuống `CommonButton`+hiện spinner, chặn `onBuy` khi loading, `loading: false` mặc định không đổi hành vi cũ, `MergeSemantics` vẫn phản ánh đúng "loading". Sửa 2 lỗi nhỏ phát sinh khi viết test: tap nhầm `find.byType(ShopItemCard)` thay vì `find.byType(CommonButton)` (đúng convention đã dùng ở các test khác trong cùng file), và `pumpAndSettle()` treo vô hạn vì `CircularProgressIndicator` animation không bao giờ settle khi `loading: true` — đổi thành `pump()`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1160/1160 pass. Không demo trong `example/` (không bắt buộc) — ưu tiên thời gian cho ENH-67/IDEA-56 còn lại trong cùng đợt làm việc.

**Tự chấm điểm: 9.5/10** — đúng yêu cầu, tái dùng triệt để `CommonButton.loading` đã có, không viết logic mới. Trừ điểm nhỏ vì không demo device thật (chấp nhận được, task ghi rõ "không bắt buộc").
