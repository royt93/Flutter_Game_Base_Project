---
id: IDEA-09
title: "Neutral remote-push seam, tách biệt ReminderService (chỉ local)"
type: idea
priority: exclusive (độ tin cậy thấp — xem ghi chú)
effort: M
source: Claude, audit round 2 (fork agent)
---

## Ý tưởng
`ReminderService` hiện chỉ lên lịch local notification. Chưa có interface
trung lập (kiểu `CrashReporter`/`AnalyticsProvider` — nhận implementation
tiêm từ app) cho app muốn dùng push thật (FCM/APNs) để re-engage người chơi,
không chỉ nhắc lịch cố định.

## Ghi chú độ tin cậy
Độ tin cậy THẤP — có thể package này cố tình muốn giữ "không phụ thuộc SDK
push" để giữ nhẹ. Cần hỏi ý kiến trước khi làm, không tự quyết định scope.

## Phụ thuộc
Không có — độc lập, nhưng nên xác nhận với chủ dự án trước khi code.
