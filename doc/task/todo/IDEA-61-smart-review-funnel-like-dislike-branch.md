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
- [ ] "Thích" trigger đúng store review flow hiện có (qua `InAppReviewHelper`).
- [ ] "Chưa thích" KHÔNG mở store review, thay vào đó mở kênh góp ý nội bộ (có thể là 1 dialog đơn giản, không cần backend thật).
- [ ] Test widget cho cả 2 nhánh.

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
