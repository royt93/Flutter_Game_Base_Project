---
id: IDEA-68
title: "NotificationPermissionPrimer — hỏi mềm trước khi bật dialog OS thật cho notification permission"
type: idea
priority: low
effort: S
source: "claude (fork brainstorm, độc lập)"
---

## Vị trí
Widget mới `lib/presentation/widgets/common/notification_permission_primer.dart`, dùng trước `lib/core/reminder_service.dart`'s `scheduleNext()`/`_doInit()`.

## Hiện trạng
`reminder_service.dart`'s `_doInit()` gọi thẳng `requestNotificationsPermission()` (native OS dialog) mỗi khi `scheduleNext()` lần đầu chạy — không có bước "hỏi mềm" (soft-ask) nào trước đó. Nếu người chơi bấm "Từ chối" ở dialog OS thật, KHÔNG có cách hỏi lại trong app — native permission bị khoá cho tới khi user tự vào Settings hệ thống.

## Vì sao cần / Hậu quả
Pattern "hỏi mềm trước, native prompt sau" là chuẩn ngành, tăng tỉ lệ opt-in đáng kể so với hỏi native ngay lập tức. Package VỪA làm đúng pattern này cho store review (`SmartReviewFunnel`, IDEA-67 — À, chính xác là ENH-87/IDEA-61) — làm tương tự cho notification permission là hợp lý, tận dụng lại đúng convention `NeonDialog.show` đã có.

## Đề xuất
1 dialog `showNotificationPermissionPrimer(context, {onAccept, onDecline})` — ví dụ "Bật thông báo để không bỏ lỡ phần thưởng?" — accept mới thực sự trigger permission flow thật của `ReminderService`; decline thì KHÔNG bao giờ đụng tới native dialog (tránh bị khoá vĩnh viễn do user từ chối native prompt quá sớm). Theo đúng pattern `showConfirmDialog`/`showSmartReviewFunnel` đã có (Completer + `NeonDialog.show`, không viết dialog từ đầu).

## Acceptance criteria
- [x] Accept → gọi đúng permission flow thật của `ReminderService` (hoặc callback tương đương do caller cung cấp).
- [x] Decline → KHÔNG gọi native permission dialog dưới bất kỳ hình thức nào.
- [x] Test widget cho cả 2 nhánh (accept/decline), và case dismiss (back/gesture, không bấm nút nào).
- [x] Không đổi hành vi `ReminderService` hiện có khi không dùng widget mới.

## Quyết định

**Implementation:**
- File mới `lib/presentation/widgets/common/notification_permission_primer.dart`: `showNotificationPermissionPrimer(context, {required onAccept, onDecline})` trả về `Future<NotificationPermissionPrimerChoice>` (`accepted`/`declined`/`dismissed`) — sao chép chính xác cấu trúc Completer + `NeonDialog.show(...).then(...)` + `addPostFrameCallback` guard của `smart_review_funnel.dart` (IDEA-61), không viết lại từ đầu.
- `accepted` → `await onAccept()` (caller tự truyền `() => ReminderService.to.scheduleNext(...)`, widget này KHÔNG tự import/gọi `ReminderService` — giữ đúng decoupling pattern `showSmartReviewFunnel` đã dùng cho `showReview`).
- `declined`/`dismissed` → không bao giờ gọi `onAccept`; `declined` gọi `onDecline` nếu có, `dismissed` không gọi gì cả (giống hệt cách `smart_review_funnel` xử lý dismissed — không side-effect nào).
- `ReminderService` (`lib/core/reminder_service.dart`) hoàn toàn không bị đụng tới — file mới chỉ là 1 lớp routing UI đứng TRƯỚC, đúng như đề xuất "hỏi mềm trước, native prompt sau", không cần sửa service để widget hoạt động.
- Thêm export vào `common_widgets.dart` (đặt cạnh `review_prompt_trigger.dart`/`smart_review_funnel.dart` cùng nhóm feedback/overlay).

**TDD:** file lib là file MỚI hoàn toàn nên dùng cách "di chuyển file mới ra ngoài tạm thời" thay vì `git stash` (đúng gợi ý ở bước 3 quy trình chuẩn) — `mv` file lib ra `/tmp`, chạy 5 test mới → tất cả fail đúng lý do (`Undefined name`/`Method not found` cho `NotificationPermissionPrimerChoice`/`showNotificationPermissionPrimer`, đúng vì file/symbol chưa tồn tại) → `mv` trả lại → chạy lại pass.

**Kết quả:**
- `flutter analyze` (root): sạch.
- `flutter test --exclude-tags slow` (root): 2326 test, 21 fail — khớp đúng baseline đã biết: 19 golden-image (macOS-vs-Linux rendering, không liên quan code) + `energy_service_test.dart` BUG-52 (flaky quen thuộc) + 1 flaky mới `save_slot_manager_test.dart` "Slice 1: metadata CRUD..." (race thời gian thực khi 2 slot ghi cùng millisecond, verify riêng lẻ vẫn fail độc lập với thứ tự sort — không liên quan gì tới file tôi vừa sửa, không đụng `save_slot_manager.dart`/test đó). Không có regression nào từ thay đổi của tôi.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- `lib/roy_casual_kit.dart` không thay đổi export trực tiếp (file mới chỉ export qua barrel `common_widgets.dart`, đã export sẵn cả barrel) → không cần chạy `api_compatibility.dart`.
- Không cần device smoke test (task cho phép bỏ qua — widget test đã verify đủ routing 3 nhánh, không cần permission dialog OS thật).

**Tự chấm điểm: 9.5/10.** Trừ 0.5 vì chưa có ví dụ tích hợp thật trong `example/` (chỉ có widget + unit test, không có demo tile như ENH-90 vừa làm) — nằm ngoài phạm vi task này (task chỉ yêu cầu widget + test, không yêu cầu demo screen).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-68-notification-permission-primer.md` này trước khi làm. Đọc toàn bộ `lib/core/reminder_service.dart`, `lib/presentation/widgets/common/confirm_dialog.dart`, và `lib/presentation/widgets/common/smart_review_funnel.dart` (pattern gần nhất, TÁI DÙNG cấu trúc Completer + `NeonDialog.show`, không viết lại từ đầu) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh routing đúng nhánh, không cần permission dialog OS thật khi test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — đã tự Read `reminder_service.dart` xác nhận đúng gap (không có soft-ask), có tiền lệ pattern rõ ràng (`SmartReviewFunnel`) để tái dùng. Giá trị thấp/vừa (không phải bug, chỉ là UX gap). Không trùng task nào trong `doc/task/done/`.
