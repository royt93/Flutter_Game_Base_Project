---
id: BUG-31
title: "StarRating: tăng số sao (earned) lúc runtime không kích hoạt lại animation pop-in"
type: bug
priority: P3
effort: S
source: Gemini (agy CLI, audit widget enhancement — tái phân loại thành bug)
---

## Vị trí
`lib/presentation/widgets/common/star_rating.dart` — `_StarRatingState`.

## Hiện trạng
`_StarRatingState` chỉ khởi động animation trong `didChangeDependencies` khi `_startedOnce == false` (tức chỉ 1 lần lúc mount). Nếu widget cha tăng `earned` sau đó (ví dụ người chơi vừa đạt thêm 1 sao trong cùng màn hình, không unmount/remount widget), `didUpdateWidget` không tồn tại — sao mới không có animation pop-in, chỉ snap tức thời.

## Vì sao cần / Hậu quả
Đây là widget "reward moment" (theo đúng tinh thần round audit animation trước) — mất animation đúng lúc cần nhất (khi số sao THỰC SỰ tăng lúc runtime, không chỉ lúc mount) là 1 lỗi chức năng về trải nghiệm, không chỉ thẩm mỹ đơn thuần.

## Đề xuất
Implement `didUpdateWidget`: khi `widget.earned > oldWidget.earned`, trigger lại animation cho (các) sao mới đạt được — theo đúng pattern `AnimationController.forward(from: 0.0)` đã thiết lập ở `StreakCounter`/`ProgressBarStars` (ENH-31/32) trong session trước, tôn trọng `NeonTheme.reducedMotion`.

## Acceptance criteria
- [ ] Tăng earned lúc runtime (không remount) trigger đúng animation pop-in cho sao mới đạt được.
- [ ] Mount lần đầu với earned đã có sẵn KHÔNG pop toàn bộ (giữ nguyên hành vi hiện tại, chỉ thêm trigger khi TĂNG lúc runtime).
- [ ] Test dùng StatefulBuilder tăng earned giữa chừng, xác nhận animation chạy (theo pattern ENH-31/32 đã dùng: đọc Transform.storage[0], không dùng getMaxScaleOnAxis()).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-31-star-rating-missing-didupdatewidget-animation-trigger.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — bug chức năng thật nhưng effort nhỏ, priority P3 vì ít nghiêm trọng hơn BUG-30 (CountdownChip có thể ảnh hưởng tới giao dịch trả phí, cái này chỉ là thiếu juice).
