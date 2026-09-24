---
id: IDEA-61
title: "Smart in-app review funnel — micro-survey 'Bạn có thích game?' trước khi mở store review, tránh 1-sao"
type: idea
priority: low
effort: S
source: "agy (độc lập) — xây trên nền ENH-87 (InAppReviewHelper wrapper) nếu cả 2 được chọn"
---

## Vị trí
Mở rộng `lib/core/in_app_review_helper.dart`, widget mới cho micro-survey.

## Hiện trạng
`InAppReviewHelper` quyết định "nên hỏi review ngay bây giờ không" nhưng khi hỏi, đi thẳng vào store review — không có bước lọc trung gian.

## Vì sao cần / Hậu quả
Người chơi không hài lòng nhưng vẫn bị đưa thẳng ra store review có thể để lại đánh giá 1 sao công khai — 1 bước lọc "Bạn có thích game không? Thích/Chưa thích" trước đó giúp điều hướng người không hài lòng sang form góp ý nội bộ thay vì store công khai.

## Đề xuất
Thêm widget `SmartReviewFunnel` hỏi trước "Thích ❤️ / Chưa thích 💔" — "Thích" mở store review thật, "Chưa thích" mở form góp ý nội bộ (hoặc đơn giản là đóng, không mở store).

## Acceptance criteria
- [x] "Thích" trigger đúng store review flow hiện có (qua `InAppReviewHelper`).
- [x] "Chưa thích" KHÔNG mở store review, thay vào đó mở kênh góp ý nội bộ (có thể là 1 dialog đơn giản, không cần backend thật).
- [x] Test widget cho cả 2 nhánh.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-61-smart-review-funnel-like-dislike-branch.md` này trước khi làm. Đọc toàn bộ `lib/core/in_app_review_helper.dart` (và `ENH-87` nếu đã làm trước — dùng đúng wrapper đã có thay vì viết lại) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (verify cả 2 nhánh, không mở store thật khi test) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng phổ biến/đã kiểm chứng trong ngành (pattern review-gating quen thuộc), giá trị thấp/vừa cho kit. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `showSmartReviewFunnel(context, {showReview, onFeedback,
...})` (`lib/presentation/widgets/common/smart_review_funnel.dart`) —
hàm `Future<SmartReviewFunnelChoice>`, KHÔNG phải widget StatefulWidget
mới nghe stream — dùng `NeonDialog.show` theo đúng convention
`showConfirmDialog` đã có (Completer + `addPostFrameCallback` guard cho
trường hợp route đóng bằng back/gesture không qua nút nào). "Thích" →
gọi `showReview()` thật (seam đã có, không invent API mới); "Chưa thích"
→ mở dialog thứ 2 (`TextField` 3 dòng + nút "Gửi góp ý"), `onFeedback`
optional nhận text đã nhập — không có `onFeedback` vẫn đóng bình thường,
không backend thật (đúng AC2 cho phép).

**Tích hợp với ENH-87**: dùng làm chính `showReview` callback của
`ReviewPromptTrigger` — doc comment ghi ví dụ cụ thể. `showSmartReviewFunnel`
là LỚP LỌC THÊM giữa "đã đến lúc hỏi" (chính sách của
`maybeRequestReview`/`ReviewPromptTrigger`) và "mở store thật", không
thay thế chính sách đó — đúng như "source" của task tự ghi ("xây trên
nền ENH-87").

**TDD**: viết test trước, `mv` file widget ra ngoài + `git stash` riêng
`common_widgets.dart` mô phỏng code cũ, chạy → fail đúng biên dịch
("Method not found: 'showSmartReviewFunnel'"), khôi phục, chạy lại —
6/6 pass. Test cover: Thích → gọi đúng `showReview`, không mở dialog góp
ý; Chưa thích → KHÔNG gọi `showReview`, mở đúng dialog góp ý; gửi góp ý
→ `onFeedback` nhận đúng text đã nhập; không có `onFeedback` → không
crash; back/gesture đóng dialog đầu (không bấm nút) → `dismissed`, không
mở gì cả (mô phỏng đúng pattern `showConfirmDialog`'s test); label tuỳ
chỉnh (title/likeLabel/dislikeLabel) dùng đúng thay mặc định.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2271 test (+6 đúng số test mới), 20 fail — 19
golden-image + 1 flaky đã biết khác (`energy_service_test.dart` BUG-52,
real-wall-clock race — loại flaky thứ 2 trong baseline đã ghi nhận từ
đầu session, không phải lỗi mới). `dart run tool/api_compatibility.dart
check` → `unchanged` (widget mới qua barrel `common_widgets.dart`, giống
pattern ENH-87/IDEA-59). Không cần smoke test device (task tự ghi optional,
không mở store thật khi test — widget test đủ chứng minh routing đúng
nhánh, không phụ thuộc SDK `in_app_review` thật nào).

Tự chấm: **9.5/10** — tái dùng đúng pattern `showConfirmDialog`/
`NeonDialog.show` có sẵn (không viết dialog từ đầu), tích hợp rõ ràng với
ENH-87 làm nền, TDD chứng minh cả nhánh chính lẫn case biên (dismiss
không qua nút, thiếu onFeedback). Trừ 0.5 vì chưa demo thật trong
`example/` (chỉ có widget + test, không có nút "Giả lập" trong
`WidgetShowcaseScreen` như `ReviewPromptTrigger` đã có ở ENH-87) — quyết
định bỏ qua vì đây là hàm show-dialog thuần, giá trị demo thêm thấp so
với thời gian, nhưng ghi nhận thiếu sót này thay vì tự nhận đã đầy đủ.
