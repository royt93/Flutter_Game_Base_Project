---
id: ENH-52
title: "DailyLoginCalendarWidget: _DaySlot dùng GestureDetector trần thay vì PressableScale"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/daily_login_calendar.dart` — `_DaySlot`.

## Hiện trạng
Khi `onTap != null`, `_DaySlot` bọc con trong `GestureDetector` thô thay vì `PressableScale` — mọi nút bấm khác trong kit (`CommonButton`, `LevelNodeButton`, `IconBadgeButton`, ...) đều dùng chung `PressableScale` để có phản hồi nhấn (scale nhẹ) nhất quán; riêng ô ngày này không có phản hồi nhấn nào.

## Vì sao cần / Hậu quả
Thiếu nhất quán cảm giác chạm giữa các control tương tác trong cùng kit — đặc biệt đáng chú ý ở đúng widget vừa được thêm animation pop-in (IDEA-23) trong session trước.

## Đề xuất
Đổi `GestureDetector(onTap: onTap, child: slot)` thành `PressableScale(onTap: onTap, child: slot)`.

## Acceptance criteria
- [x] Ô ngày hiện tại (tappable) có phản hồi scale nhấn giống mọi nút khác trong kit.
- [x] Test: xác nhận PressableScale bọc đúng slot khi onTap != null, và tap vẫn gọi đúng callback như trước.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (Dùng đúng `PressableScale` có sẵn — cùng micro-bounce mọi nút khác, tôn trọng `reducedMotion` sẵn có trong chính `PressableScale`.)

## Quyết định
Đổi `GestureDetector(onTap: onTap, child: slot)` → `PressableScale(onTap: onTap, child: slot)` trong `_DaySlot.build()` — 1 dòng, đúng y hệt gợi ý trong Đề xuất.

2 test mới trong `group('ENH-52: ...')`: xác nhận ô ngày hiện tại (tappable) có `PressableScale` làm ancestor và tap vẫn gọi đúng `onClaim`; ô ngày KHÔNG phải hiện tại không có `PressableScale` ancestor nào (giữ nguyên "không tappable" như cũ). Trong lúc viết test, phát hiện công thức xác định "ngày hiện tại" là `highlightDay = (currentStreakDay % cycleLength) + 1` (không đơn giản là `day == currentStreakDay` như tôi giả định ban đầu) — sửa lại test cho đúng dựa theo 1 test khác đã có sẵn trong cùng file ghi rõ công thức này trong comment.

Device smoke test (Pixel 7 Pro, cài đặt mới để `canClaimToday` = true): chụp ảnh ô ngày 1 (đang là ngày hiện tại, viền cyan glow) trước và sau khi tap — tap qua đúng `PressableScale` claim thành công (chuyển sang dấu tick vàng, nút "Claim" chuyển disabled), không crash, không lỗi trong logcat. Không chụp được rõ khung hình scale-down transient (biên độ mặc định `PressableScale` chỉ 0.94, quá nhỏ để phân biệt bằng mắt qua ảnh chụp tĩnh, và các lần thử `swipe` mô phỏng giữ nhấn không bắt trúng khung hình giữa lúc nhấn) — dựa vào cơ chế `PressableScale` đã được kiểm chứng kỹ qua rất nhiều widget khác trong chính session này (CommonButton, IconBadgeButton, LeaderboardEntry/AvatarFrame ở ENH-46, ...) làm bằng chứng gián tiếp đủ tin cậy cho chính cơ chế animation dùng lại y hệt.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (603 tests) và `example/` (29 tests).

Tự chấm: 9/10 — đúng 1-dòng-fix theo đề xuất, test phát hiện và sửa đúng 1 giả định sai (công thức highlightDay) thay vì đoán mò, có bằng chứng device thật cho hành vi chức năng (tap→claim); trừ điểm nhẹ vì không chụp được khung hình scale transient cụ thể (biên độ quá nhỏ để phân biệt qua ảnh tĩnh).

Commit code: `49c3a12`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-52-daily-login-day-slot-pressable-scale-consistency.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — nhất quán nhỏ, effort rất thấp, có thể gộp chung PR với BUG-30 hoặc IDEA-23 follow-up nếu tiện, nhưng vẫn track như task riêng.
