---
id: IDEA-43
title: "AchievementUnlockToast + AchievementService.onUnlock stream"
type: idea
priority: exclusive (độ tin cậy cao)
effort: M
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua agent quét codebase độc lập)
---

## Vị trí
Mở rộng `lib/core/achievement_service.dart` (thêm `onUnlock` stream); widget mới `lib/presentation/widgets/common/achievement_unlock_toast.dart`.

## Hiện trạng
`AchievementService` (có từ 0.1.0) theo dõi `register`/`incrementProgress`/`isCompleted` đầy đủ, nhưng KHÔNG có bất kỳ cách nào để caller biết CHÍNH XÁC lúc nào 1 achievement vừa chuyển từ chưa-xong sang xong (chỉ có thể tự poll `isCompleted` sau mỗi `incrementProgress`). Toàn bộ repo (kể cả `example/`) hiện không có widget nào tiêu thụ `AchievementService` — không có cách hiển thị "bạn vừa đạt thành tích X" cho người chơi, dù đây là phản hồi cốt lõi của casual game.

## Vì sao cần / Hậu quả
Thiếu event "vừa unlock" khiến mọi game dùng kit này phải tự viết lại logic so sánh trạng thái trước/sau mỗi lần gọi `incrementProgress` để biết có nên hiện thông báo hay không — dễ sai (ví dụ unlock 2 achievement cùng lúc trong 1 lần tăng lớn) và không có sẵn UI mẫu để hiện nó.

## Đề xuất
Thêm `Stream<String> get onUnlock` vào `AchievementService` (phát đúng 1 lần `achievementId` ngay tại thời điểm `incrementProgress` khiến nó CHUYỂN từ chưa-đạt sang đạt — không phát lại nếu gọi thêm sau khi đã đạt). Thêm widget `AchievementUnlockToast` (overlay tự ẩn sau X giây, animation xịn sò theo `NeonTheme` — trượt vào + bật ra `easeOutBack`) lắng nghe stream này và tự hiện, dùng đúng pattern `NeonDialog.overlay` đã có trong kit thay vì tự implement overlay mới.

## Acceptance criteria
- [ ] `onUnlock` phát đúng 1 lần mỗi achievement, đúng lúc chuyển trạng thái (không phát lại, không phát sai lúc `register` hay khi progress tăng nhưng chưa đạt ngưỡng).
- [ ] Unlock nhiều achievement cùng lúc (1 lần `incrementProgress` nhảy qua ngưỡng nhiều id khác nhau nếu áp dụng, hoặc gọi liên tiếp) đều phát đủ, đúng thứ tự.
- [ ] `AchievementUnlockToast` tự hiện khi có sự kiện, tự ẩn sau thời gian cấu hình, animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + input không hợp lệ nếu áp dụng) — unit cho stream logic, widget test cho toast + animation + reducedMotion.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) — bằng chứng cụ thể trong Quyết định.
- [ ] Animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-43-achievement-unlock-toast.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc.
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — `AchievementService` xác nhận qua grep không có widget nào trong repo tiêu thụ nó, đây là lỗ hổng thật (không phải phỏng đoán); effort M vừa phải (1 stream + 1 widget), không đụng file nhạy cảm/scope peer.
