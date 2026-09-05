---
id: FEAT-10
title: In-App Review/Update flow helper
type: feature
priority: P2
effort: S
source: agy
---

## Vì sao cần
Xin đánh giá 5 sao đúng "khoảnh khắc vui vẻ" (vừa thắng liên tiếp N màn) là
pattern lặp lại ở hầu hết casual game, hiện phải tự viết lại mỗi dự án.

## Đề xuất phạm vi
Wrapper mỏng quanh `in_app_review`: 1 hàm `maybeRequestReview({required int
recentWinStreak, required bool everDeclined})` — chỉ trigger dialog khi đủ
điều kiện, tự nhớ đã hỏi rồi (qua `StorageService`) để không hỏi lại quá dày.

## Acceptance criteria
- [ ] Gọi liên tục nhiều lần trong session không hỏi lại nếu đã hỏi gần đây (cooldown cấu hình được).
- [ ] Test logic điều kiện trigger (không cần mock `in_app_review` thật, chỉ test phần quyết định có nên hỏi hay không).
