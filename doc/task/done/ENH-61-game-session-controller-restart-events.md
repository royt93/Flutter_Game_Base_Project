---
id: ENH-61
title: "GameSessionController.restart(): events phình vô hạn qua nhiều lần restart + chưa có test"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/game_session_controller.dart` + `test/core/game_session_controller_test.dart`)
---

## Vị trí
Sửa — `lib/core/game_session_controller.dart` (`GameSessionController.restart()`), thêm test — `test/core/game_session_controller_test.dart`.

## Hiện trạng
`events` là 1 `RxList<GameSessionPhase>` ghi lại mọi lần chuyển phase (`_transition`/`restart` đều `events.add(...)`), không có giới hạn, không bao giờ được xoá — kể cả khi `restart()` được gọi. Với 1 game restart nhiều lần trong 1 phiên chơi dài (ví dụ endless-runner, hoặc người chơi thua-thử lại hàng trăm lần), danh sách này phình lên vô hạn theo suốt vòng đời app, không phản ánh đúng ý định "lịch sử của phiên HIỆN TẠI" mà tên field gợi ý. Xác nhận qua grep: `test/core/game_session_controller_test.dart` (60 dòng, 3 test) hoàn toàn KHÔNG có test nào cho `restart()`.

## Vì sao cần / Hậu quả
Rò rỉ bộ nhớ chậm (nhỏ nhưng thật) trong 1 phiên chơi dài nhiều restart; và hành vi hiện tại (giữ lại lịch sử QUA MỌI lần restart) chưa từng được xác nhận là chủ đích qua test — dễ là 1 bug tiềm ẩn hơn là thiết kế có chủ đích.

## Đề xuất
`restart()` nên reset `events` về danh sách chỉ chứa `GameSessionPhase.loading` (khớp đúng ý "phiên mới bắt đầu") thay vì `add` nối vào lịch sử cũ. Thêm test xác nhận: (1) `restart()` reset đúng `snapshot` VÀ `events`; (2) nhiều lần restart liên tiếp không làm `events` phình to theo số lần restart.

## Acceptance criteria
- [x] `restart()` reset `events` về `[GameSessionPhase.loading]` (không còn giữ lịch sử của phiên trước).
- [x] Gọi `restart()` 100 lần liên tiếp: `events.length` không tăng theo số lần gọi (giữ nguyên `== 1` sau mỗi lần).
- [x] Hành vi `snapshot`/các transition khác (start/win/lose/pause/resume) không đổi — chỉ sửa đúng `restart()`.
- [x] Test: đủ test cho case trên; không phá 3 test hiện có.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không có animation mới cần thiết (thay đổi core controller thuần).

## Quyết định

Đúng như "Ghi chú độ tin cậy" dự đoán: `restart()` chỉ `events.add(GameSessionPhase.loading)`, không reset — viết test trước (`test/core/game_session_controller_test.dart`, nhóm "ENH-61") xác nhận đúng bug (100 lần restart → `events.length == 100` thay vì `1`), sau đó sửa 1 dòng: `events.assignAll([GameSessionPhase.loading])` thay cho `events.add(...)`. Không đổi bất kỳ transition nào khác (`markReady`/`start`/`win`/`lose`/`pause`/`resume`).

**Test:** 4 test mới — reset đúng `events`/`snapshot`, 100 lần restart không phình, các transition khác vẫn hoạt động đúng sau khi restart. 3 test cũ không đổi, vẫn pass.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1072/1072 pass. Không đụng `example/` (đúng theo Prompt — controller thuần, không có UI liên quan).

**Tự chấm điểm: 9.5/10** — sửa đúng 1 dòng, đúng phạm vi, TDD bắt đúng bug trước khi sửa, không phá gì khác. Trừ điểm nhỏ vì đây là fix rất nhỏ, không có gì phức tạp để thể hiện thêm.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-61-game-session-controller-restart-events.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/game_session_controller.dart` và `test/core/game_session_controller_test.dart` hiện có để chắc chắn không phá 3 test đang pass. Implement bằng TDD (viết test fail trước, code cho pass — viết test xác nhận đúng bug hiện tại trước khi sửa, giống cách TDD đã bắt bug thật ở các task trước trong session này).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá test/hành vi hiện có ngoài đúng phạm vi `restart()`, không over-engineer — ví dụ không cần thêm giới hạn dung lượng `events` nếu chỉ `restart()` mới cần reset).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (không cần đụng `example/` — đây là controller thuần, không có UI liên quan trực tiếp).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `game_session_controller.dart` (`restart()` chỉ `events.add(...)`, không reset) và grep `test/core/game_session_controller_test.dart` (0 test nào nhắc tới `restart`). Effort rất nhỏ (sửa đúng 1 dòng logic + thêm test), không đụng file nhạy cảm/scope peer.
