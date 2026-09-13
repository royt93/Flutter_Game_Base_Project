---
id: IDEA-33
title: "PurchaseLedgerService — lớp sổ cái cục bộ đơn giản trên PurchaseSeam cho consumable/permanent"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: S
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/core/purchase_seam.dart`, `lib/presentation/widgets/common/shop_item_card.dart`.

## Hiện trạng
`PurchaseSeam` (vừa thêm ở IDEA-15) cố tình tối giản (`buy`/`restorePurchases`/`isOwned`), đẩy việc "xác thực receipt, mô hình hoá consumable/subscription" cho adapter thật của app. Nhưng có 1 lớp sổ sách RẤT phổ biến ("sở hữu vĩnh viễn 1 lần, theo dõi số lượng còn lại của 1 consumable") mà HẦU HẾT adapter `PurchaseSeam` sẽ phải tự viết lại giống nhau.

## Vì sao cần / Hậu quả
Mỗi game tích hợp `PurchaseSeam` đều phải tự viết lại logic sổ sách cơ bản này — trùng lặp không cần thiết giữa các dự án dùng chung package.

## Đề xuất
`PurchaseLedgerService extends GetxService` trên nền `VersionedJsonStore` — `grantConsumable(sku, amount)`/`consume(sku, amount)`/`grantPermanent(sku)`/`owns(sku)` — 1 cache cục bộ mỏng mà adapter `PurchaseSeam` thật của app ghi vào SAU KHI đã xác thực giao dịch, không thay thế xác thực receipt phía server.

## Acceptance criteria
- [ ] grantConsumable/consume/grantPermanent/owns hoạt động đúng, consume không cho về âm số dư.
- [ ] Doc comment ghi rõ đây KHÔNG phải lớp xác thực receipt — chỉ là cache cục bộ sau khi PurchaseSeam adapter đã xác nhận giao dịch thật.
- [ ] Test: grant rồi consume đúng số dư, consume vượt quá số dư hiện có bị từ chối, grantPermanent + owns() trả về true bền vững qua restart (persist qua VersionedJsonStore).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-33-purchase-ledger-service.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — bổ sung hợp lý cho `PurchaseSeam` vừa thêm, effort thấp, giá trị phụ thuộc việc game có nhiều loại consumable cần theo dõi hay chỉ vài permanent purchase đơn giản.
