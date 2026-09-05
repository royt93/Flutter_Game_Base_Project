---
id: BUG-05
title: ReminderService dùng exactAllowWhileIdle nhưng thiếu quyền, lỗi bị nuốt âm thầm
type: bug
priority: P1
effort: M
verified: true
source: Claude-CLI + agy, verify lại AndroidManifest thật
---

## Vị trí
`lib/core/reminder_service.dart:48` (`androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`)

## Vấn đề
`example/android/app/src/main/AndroidManifest.xml` chỉ khai báo
`POST_NOTIFICATIONS`, KHÔNG khai báo `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`
(đã grep xác nhận). Trên Android 13+, gọi `zonedSchedule` với mode `exact*` mà
thiếu quyền này sẽ throw ở tầng platform channel. Lỗi bị `catch (e) { dlog(...) }`
nuốt gọn — không crash, nhưng tính năng nhắc chơi lại **âm thầm không hoạt
động**, không ai biết trừ khi đọc log debug.

Google Play cũng hạn chế app thường dùng exact alarm không lý do chính đáng —
game nhắc quay lại chơi không cần độ chính xác đó.

## Đề xuất fix
Đổi `androidScheduleMode` sang `AndroidScheduleMode.inexactAllowWhileIdle`
(đủ tốt cho reminder loại "come back and play"), đồng thời thêm bước xin
quyền `POST_NOTIFICATIONS` runtime (Android 13+) trước khi schedule lần đầu.

## Acceptance criteria
- [ ] Không cần khai báo `SCHEDULE_EXACT_ALARM` mà reminder vẫn lên lịch được.
- [ ] Có bước request permission runtime, log rõ khi bị từ chối (không chỉ dlog im lặng).
