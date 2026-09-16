---
id: IDEA-53
title: "CommonButton: thêm trạng thái loading (spinner + tự disable) khi đang chờ 1 hành động async"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/presentation/widgets/common/common_button.dart`, `backup_restore_panel.dart`, `shop_item_card.dart`)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/common_button.dart` (`CommonButton`).

## Hiện trạng
`CommonButton` chỉ có 2 trạng thái: enabled (`onTap != null`) và disabled (`onTap == null`) — không có khái niệm "đang xử lý" (ví dụ: đang chờ 1 lệnh mua IAP qua `PurchaseSeam`, đang chờ 1 `Future` từ `EconomyWallet.earn`/`trySpend`, đang chờ network trong `RemoteConfigService`). `backup_restore_panel.dart` đã tự tay dựng 1 pattern "spinner cạnh nút, `_busy` tự quản trong State riêng" để giải quyết đúng nhu cầu này cho panel đó — nghĩa là nhu cầu có thật, nhưng không tái dùng được ở nơi khác vì nó không nằm trong chính `CommonButton`. `ShopItemCard`'s nút "Buy" (bọc `CommonButton`) là ví dụ rõ nhất khác đang thiếu: bấm mua xong, nếu `onBuy` là 1 hành động async (gọi ra `PurchaseSeam`/store thật), người chơi có thể bấm lại nhiều lần trong lúc chờ phản hồi — không có gì ngăn double-tap ở tầng UI (dù `EconomyWallet`/`PurchaseLedgerService` có thể tự chống trùng ở tầng dữ liệu, tầng UI vẫn nên tự khoá lại, đúng 2 lớp phòng thủ).

## Vì sao cần / Hậu quả
Không có state này trong chính widget dùng chung, mỗi màn hình cần "nút xử lý async" phải tự dựng lại pattern y hệt `backup_restore_panel.dart` đã làm — trùng lặp code, dễ lệch UX (nơi disable đúng, nơi quên disable, nơi hiện spinner khác kiểu). Đây là khoảng trống rõ ràng giữa 1 widget dùng chung phổ biến nhất (`CommonButton` đã dùng trong gần như mọi demo/widget khác trong `common/`) và 1 nhu cầu UX rất phổ biến của casual game (mua hàng, lưu game, đồng bộ cloud).

## Đề xuất
Thêm 1 param `bool loading = false` vào `CommonButton`:
- Khi `loading == true`: nút tự coi như disabled (bỏ qua `onTap` dù khác null — không cho bấm lại trong lúc đang xử lý), thay label/icon bằng 1 `CircularProgressIndicator` nhỏ (cùng kích thước khoảng cách như `backup_restore_panel.dart` đã dùng — `strokeWidth: 2`, size nhỏ ~16-18), giữ nguyên `width`/kích thước tổng thể của nút (không để layout nhảy khi chuyển qua lại loading/không-loading).
- Semantics: khi loading, label nên phản ánh đúng trạng thái (ví dụ tự thêm "loading"/giữ nguyên label kèm cờ busy) — không được để mất hẳn ngữ nghĩa của nút.
- Không đổi hành vi mặc định khi `loading` không truyền vào (default `false` = y hệt hiện tại) — không phá bất kỳ call site nào đang dùng `CommonButton`.

## Acceptance criteria
- [x] `loading: true`: nút không gọi `onTap` dù `onTap` khác null (double-tap trong lúc loading bị chặn).
- [x] `loading: true`: hiện spinner thay cho label/icon, không làm nút đổi kích thước tổng thể (width/height ổn định giữa 2 trạng thái).
- [x] `loading: false` (mặc định): hành vi y hệt hiện tại, không phá bất kỳ test/call site nào đang có (`ShopItemCard`, `QuestBoardPanel`, v.v.).
- [x] Semantics: `enabled` phản ánh đúng false khi loading; label không bị mất ý nghĩa (không hiện label rỗng/gây hiểu lầm nút không làm gì).
- [x] Test: widget test đầy đủ mọi case trên (tap trong lúc loading không kích hoạt callback, spinner hiện đúng, kích thước ổn định, Semantics đúng).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` — nếu muốn minh hoạ, cân nhắc wire vào 1 nút demo giả lập async trong `widget_showcase_screen.dart` (không bắt buộc).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-53-common-button-loading-state.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/presentation/widgets/common/common_button.dart` và `test/widget/common/common_button_test.dart` hiện có để hiểu đúng cấu trúc `_buildPill`/`_buildIcon`/Semantics hiện tại trước khi thêm state mới — không viết lại toàn bộ widget, chỉ thêm đúng nhánh cần thiết. Xem qua cách `backup_restore_panel.dart` (dòng có `CircularProgressIndicator`) đã tự dựng spinner để tham khảo kích thước/màu sắc nhất quán, nhưng KHÔNG copy nguyên state `_busy` riêng của nó — đây là task thêm vào chính `CommonButton`. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — chỉ 1 param bool + 1 nhánh hiển thị, không thêm animation controller mới nếu implicit animation đủ dùng cho việc chuyển đổi label/spinner).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên wire vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android/iOS thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator), chụp screenshot làm bằng chứng, ghi vào `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `common_button.dart`: không có field `loading`/`busy` nào tồn tại, chỉ `onTap` quyết định enabled/disabled. Xác nhận qua đọc `backup_restore_panel.dart` (dòng dùng `CircularProgressIndicator` cạnh trạng thái `_busy` riêng) rằng nhu cầu "nút + spinner khi đang xử lý" đã từng phải tự tay giải quyết ở nơi khác thay vì tái dùng `CommonButton`, và qua đọc `test/widget/common/common_button_test.dart` xác nhận chưa có test nào cho `loading`. Effort nhỏ (1 param bool + 1 nhánh hiển thị trong widget đã có), không đụng file nhạy cảm/scope peer.

## Quyết định

Thêm `bool loading = false` vào `CommonButton`, tách rõ 2 khái niệm trước đây gộp chung vào 1 getter `_enabled`:

- `_enabled` (giữ nguyên tên/ý nghĩa cũ: `onTap != null`) — chỉ quyết định MÀU SẮC/shadow. Quyết định có chủ đích: nút khi `loading` vẫn giữ nguyên màu accent/shadow, KHÔNG chuyển sang màu muted như khi disabled thật — về mặt UX "đang xử lý" khác hẳn "không dùng được", muted sẽ gây hiểu lầm.
- `_tappable` (mới: `onTap != null && !loading`) — quyết định Semantics `enabled` và có truyền `onTap` xuống `PressableScale` hay không (`null` khi loading → double-tap không kích hoạt được).
- Hiển thị spinner: dùng `Stack` với `Opacity(opacity: loading ? 0 : 1, child: <Row nội dung gốc>)` xếp chồng `CircularProgressIndicator` — nội dung gốc VẪN được layout (chỉ ẩn), nên kích thước Container không đổi giữa 2 trạng thái mà không cần đo/ghim kích thước thủ công. Variant `icon` đơn giản hơn (Container đã có `width`/`height` cố định `d` sẵn, không cần `Stack`) — chỉ swap `Icon` ↔ spinner trực tiếp.
- Semantics label: khi loading, nối thêm `', loading'` vào label gốc (`'$baseLabel, loading'`) — không mất ý nghĩa nút, đúng yêu cầu.

**Test:** 7 test mới trong `test/widget/common/common_button_test.dart` nhóm "IDEA-53" — chặn tap khi loading, hiện đúng `CircularProgressIndicator` (cả 2 variant pill/icon), kích thước ổn định (dung sai 1 logical pixel cho pill — chênh lệch sub-pixel từ `Stack`/`TextPainter`, không phải nút đổi kích thước thấy được; variant icon khớp tuyệt đối vì `Container` có `width`/`height` cố định), `loading: false` mặc định không đổi hành vi cũ, Semantics `enabled` đúng `false` khi loading, label vẫn giữ ý nghĩa. Đã sửa 1 API deprecated phát sinh khi viết test (`hasFlag` → `flagsCollection.isEnabled.toBoolOrNull()`, đúng convention đã dùng ở các test khác trong repo).

**Demo trong `example/`**: thêm nút "Simulate async" cạnh các demo `CommonButton` khác trong `widget_showcase_screen.dart` — giả lập 1 hành động async 1.5s (mô phỏng đúng kịch bản "Buy"/save/cloud-sync nêu trong Hiện trạng), toggle `loading` qua `setState`.

**Device smoke test (Galaxy A11, `R9JN61LDLFJ`, thiết bị thật)**: bấm "Simulate async" → bắt đúng khoảnh khắc spinner hiện (kích thước nút giữ nguyên, label ẩn đi) bằng cách gọi tap + screenshot trong CÙNG 1 lượt gọi tool (round-trip riêng lẻ luôn trễ hơn 1.5s, bỏ lỡ khung hình loading) — xác nhận đúng UI thật trên máy, không phải chỉ đúng trên test giả lập. Đợi hết 1.5s, nút tự trở lại đúng label "Simulate async", bấm lại vẫn hoạt động bình thường. `adb logcat` lọc `level=Error` trước/sau: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1123/1123 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 52/52 pass (bao gồm 1 test mới cho demo, đã sửa lỗi StrokeText double-render quen thuộc bằng `findsWidgets`).

**Tự chấm điểm: 9.5/10** — đúng mọi acceptance criteria, thiết kế tách bạch rõ ràng 2 khái niệm màu sắc vs khả năng tương tác (quyết định UX có chủ đích, không mặc định coi loading = disabled), dùng `Stack`+`Opacity` để giữ kích thước ổn định thay vì đo/ghim thủ công (đơn giản, đúng tinh thần "không over-engineer" trong Prompt), có bằng chứng device thật bắt đúng khung hình loading bằng kỹ thuật gọi tool đồng thời thay vì bỏ cuộc trước độ trễ round-trip. Trừ điểm nhỏ vì dung sai 1px trong test kích thước pill là 1 giới hạn kỹ thuật đã biết (sub-pixel rounding của `Stack`/`TextPainter`), không phải độ chính xác tuyệt đối 100%.
