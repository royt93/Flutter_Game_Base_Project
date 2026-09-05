---
id: ENH-05
title: ReminderService kế thừa GetxController, khác base với 3 service còn lại
type: enhance
priority: P2
effort: S
source: Claude-CLI, verify lại code thật
---

## Hiện trạng
`StorageService`, `LocaleService`, `AudioManager` đều extends `GetxService`
(singleton, không bị GetX tự dispose theo route/binding). `ReminderService`
lại extends `GetxController` (lifecycle gắn với controller thường, có thể bị
GetX dispose nếu đăng ký sai chỗ) — không nhất quán giữa các core service
"permanent" của kit.

## Đề xuất
Đổi `ReminderService` sang `extends GetxService` cho nhất quán, trừ khi có lý
do cụ thể cần lifecycle của `GetxController` (chưa thấy trong code hiện tại).

## Acceptance criteria
- [ ] `ReminderService extends GetxService`.
- [ ] `Get.put(ReminderService(), permanent: true)` ở `main.dart` vẫn hoạt động, test liên quan vẫn pass.
