---
id: ENH-44
title: "ShopItemCard: nút mua hardcode variant primary + màu cyan mặc định, không aggregate semantics"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/shop_item_card.dart`.

## Hiện trạng
`CommonButton` bên trong hardcode `primary` variant và màu mặc định cyan, không expose `buttonColor`/`buttonVariant` cho caller tuỳ biến (ví dụ 1 item "best value" muốn nút màu vàng nổi bật hơn). Card cũng không gộp nội dung thành 1 node semantics duy nhất cho screen reader (liên quan ENH-37 sweep nhưng đủ cụ thể để tách riêng vì đụng logic nút bấm, không chỉ thêm Semantics đơn thuần).

## Vì sao cần / Hậu quả
Hạn chế tuỳ biến trực quan cho các item "nổi bật"/"best value" khác nhau trong cùng 1 shop screen.

## Đề xuất
Thêm tham số optional `Color? buttonColor`, `CommonButtonVariant buttonVariant = CommonButtonVariant.primary`. Gộp nội dung card (title + price + ribbon nếu có) vào 1 `Semantics(label: ...)` bao ngoài.

## Acceptance criteria
- [ ] buttonColor/buttonVariant khi truyền áp dụng đúng cho nút mua, mặc định giữ nguyên hành vi hiện tại.
- [ ] Semantics gộp đọc đúng title + priceLabel + ribbonText (nếu có) thành 1 câu duy nhất.
- [ ] Test: truyền buttonColor custom xác nhận CommonButton nhận đúng màu; tester.getSemantics xác nhận label gộp đúng nội dung.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-44-shop-item-card-button-customization.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API ergonomics + accessibility nhỏ, effort thấp.
