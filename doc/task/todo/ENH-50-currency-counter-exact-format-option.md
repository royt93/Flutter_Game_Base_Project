---
id: ENH-50
title: "CurrencyCounter: luôn ép dùng fmtNumCompact (1.5K), không có lựa chọn hiển thị số chính xác"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/currency_counter.dart`.

## Hiện trạng
Widget luôn format qua `fmtNumCompact` (ví dụ 1500 → "1.5K") — game cần hiển thị số chính xác (ví dụ "1,500" cho số tiền nhỏ, chỉ compact khi số lớn) phải tự viết widget đếm số khác từ đầu.

## Vì sao cần / Hậu quả
Hạn chế use-case rất phổ biến: nhiều game chỉ compact hoá số RẤT lớn (>= 10,000 hoặc 100,000), không phải mọi con số.

## Đề xuất
Thêm tham số optional `bool compact = true` (dùng `fmtNum` thay `fmtNumCompact` khi `false`), hoặc linh hoạt hơn `String Function(int)? formatter` cho phép caller tự quyết định hoàn toàn công thức hiển thị — chọn hướng đơn giản nhất khi code (khả năng cao chỉ cần `bool compact` là đủ, đừng thêm `formatter` nếu không có ai cần).

## Acceptance criteria
- [ ] compact: false hiển thị số chính xác qua fmtNum, compact: true (mặc định) giữ nguyên hành vi hiện tại.
- [ ] Test: cùng 1 giá trị lớn (ví dụ 12345678) với compact true/false hiển thị đúng 2 định dạng khác nhau.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-50-currency-counter-exact-format-option.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API ergonomics, effort thấp.
