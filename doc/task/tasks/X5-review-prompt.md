# X5 — Review prompt đúng lúc

**Epic:** Floor/UX · **SP:** 2 · **Pri:** Should · **Deps:** F7 (mốc tích cực để trigger)

## Mục tiêu
1 lần duy nhất trong đời cài đặt, sau 1 mốc tích cực (vd thắng level thứ N
hoặc đạt 3 sao liên tiếp), hiện prompt đánh giá app store gốc.

## Vì sao
Gap floor phổ biến ở casual game — chưa có review prompt, và trigger đúng
lúc (sau thắng, không phải sau thua) tăng tỉ lệ review tích cực.

## Acceptance criteria
- [x] Cờ `hasShownReviewPrompt` (`StorageKeys` mới) — chỉ hiện đúng 1 lần.
- [x] Trigger tại mốc tích cực cụ thể (không hiện ngay sau thua/thoát giữa
      chừng).
- [x] Dùng plugin review gốc hệ điều hành (kiểm tra `pubspec.yaml` đã có
      package review chưa trước khi thêm mới).
- [x] Unit test: hàm điều kiện trigger đúng, không hiện lại lần 2.

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `StorageKeys.hasShownReviewPrompt`; hàm thuần
`GameController.shouldRequestReview({stars, alreadyShown})` (`stars == 3 &&
!alreadyShown`) tách riêng để test được, gọi từ `_maybeRequestReview()` chỉ
khi vừa đạt mốc 3 sao; dùng `in_app_review: ^2.0.12` (`pubspec.yaml:48`) qua
`InAppReview.instance.requestReview()`, không tự viết dialog riêng; unit test
`shouldRequestReview` có trong `test/presentation/game_controller_test.dart`.

## Subtasks (gợi ý file)
1. `lib/core/storage_service.dart`: key `hasShownReviewPrompt`.
2. `lib/presentation/controllers/game_controller.dart`: gọi check trong
   `checkEnd` tại mốc phù hợp.
3. Thêm package review (nếu chưa có) qua `pubspec.yaml`.

## Ghi chú kỹ thuật
Kiểm tra pubspec trước khi thêm dependency mới — ưu tiên tái dùng nếu đã có
sẵn.

DoD chung: `../README.md`.
