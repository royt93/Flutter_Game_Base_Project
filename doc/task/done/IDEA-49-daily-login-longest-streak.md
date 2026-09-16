---
id: IDEA-49
title: "DailyLoginService: lưu kỷ lục streak dài nhất từng đạt (longestStreakEver)"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/daily_login_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/daily_login_service.dart` (`DailyLoginService`).

## Hiện trạng
`DailyLoginService` chỉ lưu `currentStreakDay` (vị trí trong chu kỳ 7 ngày HIỆN TẠI, reset về 1 khi bỏ lỡ 1 ngày). Không có nơi nào lưu "streak dài nhất từng đạt được" (ví dụ: đã từng đăng nhập liên tục 23 ngày trước khi bỏ lỡ) — đây là số liệu rất phổ biến cho achievement ("đạt streak 30 ngày"), màn hình thống kê người chơi, hoặc leaderboard riêng về độ chuyên cần. Hiện tại thông tin này BỊ MẤT vĩnh viễn ngay khi streak reset, vì service chỉ lưu vị trí trong chu kỳ 7 ngày, không lưu độ dài streak liên tục thật sự (số ngày liên tiếp có thể vượt quá 7, chu kỳ chỉ lặp lại 1-7 để hiện lịch, không phải đếm tổng số ngày liên tục).

## Vì sao cần / Hậu quả
Không track được, mọi game dùng service này muốn có achievement "streak dài nhất" hoặc thống kê profile phải tự implement song song — dễ lệch logic reset/tiếp tục với chính service đang track (2 nguồn sự thật cho cùng 1 khái niệm "đang tiếp tục streak hay không").

## Đề xuất
Thêm field mới `longestStreakEver` (số ngày liên tục tối đa từng đạt được — KHÁC `currentStreakDay` là vị trí trong chu kỳ 7 ngày; cần 1 counter riêng đếm số ngày liên tục thật, không giới hạn ở 7, chỉ reset về 1 khi thật sự bỏ lỡ 1 ngày). Expose qua getter `int get longestStreakEver`. Cập nhật trong `claimToday()`: nếu streak liên tục hiện tại (không phải vị trí chu kỳ) vượt quá kỷ lục cũ, cập nhật kỷ lục. Migrate: field mới trong schema, `migrate` hook hiện tại (`(fromVersion, json) => json`) cần xử lý JSON cũ thiếu field này (mặc định 0 hoặc bằng streak liên tục đã tính được tại thời điểm parse).

## Acceptance criteria
- [x] `longestStreakEver` bắt đầu ở 0, tăng đúng theo số ngày liên tục thật (không phải vị trí chu kỳ 1-7 — ví dụ ngày liên tục thứ 10 vẫn phải ghi nhận kỷ lục 10, dù vị trí chu kỳ lúc đó là 3).
- [x] Streak reset (bỏ lỡ 1 ngày): `longestStreakEver` GIỮ NGUYÊN giá trị kỷ lục cũ, không bị reset về 0.
- [x] Claim cùng ngày nhiều lần (no-op theo `canClaimToday()`): không tăng `longestStreakEver` sai.
- [x] JSON cũ (từ trước khi có field này) load được, không throw, `longestStreakEver` có giá trị hợp lý (0 hoặc suy ra đúng từ state cũ).
- [x] JSON hỏng/field sai kiểu cho field mới: rơi về `_DailyLoginState.initial` an toàn (đúng convention "domain trust boundary" đã ghi trong code hiện tại), không throw.
- [x] Test: unit test đầy đủ cho mọi case trên, bao gồm chuỗi claim nhiều ngày liên tục qua streak reset để xác nhận kỷ lục không mất.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không có animation mới cần thiết (thay đổi core service thuần).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-49-daily-login-longest-streak.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/daily_login_service.dart` và test hiện có (`test/core/daily_login_service_test.dart` nếu tồn tại) để hiểu đúng sự khác biệt giữa "vị trí trong chu kỳ 7 ngày" (`streakDay`) và "số ngày liên tục thật" — cần thêm 1 counter mới cho khái niệm thứ 2, KHÔNG nhầm lẫn với `streakDay` hiện có. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test/migration hiện có, xử lý đúng migration cho JSON cũ thiếu field mới, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên hiện `longestStreakEver` ở đâu đó trong demo `example/` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/`: smoke test thật trên máy Android thật hiện có (kiểm tra `mobile_list_available_devices` trước, KHÔNG dùng simulator/emulator), chụp screenshot làm bằng chứng, ghi vào `## Quyết định`. Kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác (thiết bị có thể chia sẻ với peer session khác).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `daily_login_service.dart`: hiện chỉ có `streakDay` (vị trí chu kỳ 1-7), không có counter số ngày liên tục thật nào. Effort nhỏ-vừa (cần thêm 1 field + xử lý migration schema cẩn thận), không đụng file nhạy cảm/scope peer.

## Quyết định

Thêm 2 field mới vào `_DailyLoginState`: `currentRunLength` (số ngày liên tục THẬT, không giới hạn 7 như `streakDay`) và `longestStreakEver` (kỷ lục cao nhất từng đạt). `claimToday()` tính `nextRunLength = streakWasReset ? 1 : state.currentRunLength + 1` rồi `nextLongest = max(nextRunLength, state.longestStreakEver)` — dùng lại đúng biến `streakWasReset` đã có sẵn trong hàm, không cần logic phát hiện reset riêng.

**Migration JSON cũ**: phân biệt rõ "key vắng mặt" (save cũ trước khi field này tồn tại — coi là hợp lệ, suy luận `currentRunLength` từ `streakDay` cũ) với "key có mặt nhưng sai kiểu" (dữ liệu hỏng thật — rơi về `_DailyLoginState.initial`, đúng convention "domain trust boundary" các field khác trong file đã dùng). Thêm invariant `longestStreakEver >= currentRunLength` và `last == -1 ⟺ currentRunLength == 0` vào cùng khối validate hiện có.

**Test:** 9 test mới trong `test/core/daily_login_service_test.dart` nhóm "IDEA-49" — bắt đầu ở 0, tăng đúng qua mốc 7 ngày (ngày liên tục thứ 10 ghi đúng kỷ lục 10 dù vị trí chu kỳ chỉ là 3), streak reset giữ nguyên kỷ lục cũ, claim cùng ngày không tăng sai, run mới vượt kỷ lục cũ cập nhật đúng, JSON cũ thiếu field load được, JSON hỏng (sai kiểu / vô lý logic) rơi về initial, và persist đúng qua "restart". Tất cả pass ngay lần chạy đầu tiên sau khi implement (không có bug logic nào TDD bắt được lần này, khác các task trước).

**Demo trong `example/`**: thêm 1 dòng `Text('Longest streak ever: N')` ngay dưới `DailyLoginCalendarWidget` trong `widget_showcase_screen.dart` — không cần widget mới, tái dùng đúng field `_dailyLogin.longestStreakEver` đã public.

**Device smoke test (Pixel 7 Pro, `2B051FDH3006MU`, thiết bị thật)**: mở app, cuộn tới `DailyLoginCalendarWidget`, xác nhận "Longest streak ever: 0" hiện đúng lúc chưa claim gì; double-tap ô "1" để claim thật → cập nhật ngay thành "Longest streak ever: 1", không crash. `adb logcat` lọc `level=Error`: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1098/1098 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 51/51 pass (bao gồm 1 widget test mới cho dòng text).

**Tự chấm điểm: 9.5/10** — đúng mọi acceptance criteria, phân biệt rõ ràng và đúng đắn giữa "field vắng mặt" (migrate mềm) và "field sai kiểu" (coi là hỏng) — đúng tinh thần trust-boundary nhất quán với phần còn lại của file thay vì áp dụng 1 rule chung chung cho tất cả trường hợp thiếu dữ liệu. Có bằng chứng device thật xác nhận đúng hành vi tăng dần qua 1 lần claim thật. Trừ điểm nhỏ vì lần này TDD không bắt được bug nào trước khi lên máy — thiết kế đơn giản, ít bề mặt lỗi hơn các task RNG/replay trước đó.
