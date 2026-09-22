---
id: ENH-87
title: "InAppReviewHelper không có widget/listener wrapper hay demo — service đúng loại cần trigger đúng lúc lại thiếu counterpart UI"
type: enhancement
priority: P2
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/core/in_app_review_helper.dart`, so sánh với `lib/presentation/widgets/achievement_unlock_listener.dart` (`AchievementUnlockListener` bọc `AchievementService` — đúng pattern "core service có timing logic → widget listener kèm theo").

## Hiện trạng
`InAppReviewHelper` chứa decision logic "nên hỏi đánh giá app ngay bây giờ không" (đúng thời điểm sau 1 khoảnh khắc vui — pattern casual-game kinh điển) nhưng không có widget wrapper nào tự động lắng nghe đúng thời điểm và trigger review prompt, khác với `AchievementService` đã có `AchievementUnlockListener` làm đúng việc này. Cũng không có demo trong `example/`.

## Vì sao cần / Hậu quả
1 dev tích hợp phải tự viết code lắng nghe đúng "khoảnh khắc vui" (ví dụ sau khi thắng level) rồi gọi `InAppReviewHelper` thủ công — không có ví dụ/widget tiện lợi nào để copy, dù kit đã có tiền lệ pattern này cho `AchievementService`.

## Đề xuất
Thêm 1 widget/listener nhỏ (ví dụ `ReviewPromptTrigger`) nhận 1 `Stream`/callback "khoảnh khắc vui" (ví dụ `onLevelWon`) và tự gọi `InAppReviewHelper.maybeRequestReview()` đúng lúc theo policy có sẵn. Thêm demo trong `example/` minh hoạ cách nối 1 sự kiện thắng level giả lập với helper này.

## Acceptance criteria
- [ ] Có 1 widget/helper wrapper mới bọc `InAppReviewHelper`, theo đúng pattern `AchievementUnlockListener` đã có.
- [ ] Demo trong `example/` minh hoạ trigger review prompt sau 1 sự kiện giả lập (ví dụ nút "Giả lập thắng level").
- [ ] Test widget verify wrapper gọi đúng `InAppReviewHelper` API khi điều kiện thoả, không gọi khi chưa đủ điều kiện (policy: không hỏi quá thường xuyên).
- [ ] Không đổi hành vi `InAppReviewHelper` core logic hiện có.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-87-in-app-review-helper-no-wrapper-or-demo.md` này trước khi làm. Đọc toàn bộ `lib/core/in_app_review_helper.dart` và `lib/presentation/widgets/achievement_unlock_listener.dart` (pattern tham khảo) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (verify demo trigger đúng, không double-prompt) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — so sánh hợp lý với tiền lệ `AchievementUnlockListener` đã có trong repo (xác nhận file tồn tại theo CLAUDE.md). Không trùng task nào trong `doc/task/done/`. Lưu ý: khác với IDEA-61 (smart review funnel like/dislike) — task này chỉ là "có wrapper/demo cơ bản", IDEA-61 là 1 tính năng branching UX cụ thể hơn xây TRÊN nền tảng ENH-87 nếu cả 2 được chọn.
