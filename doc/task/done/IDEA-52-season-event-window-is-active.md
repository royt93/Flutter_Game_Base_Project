---
id: IDEA-52
title: "SeasonEventWindow: thêm isActive để không cần tự so sánh DateTime thủ công"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/season_event_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/season_event_service.dart` (`SeasonEventWindow`, `SeasonEventService`).

## Hiện trạng
`SeasonEventService.currentWindow(eventId, length: ..., cooldown: ...)` trả về `SeasonEventWindow(start, end)` — nhưng đây LUÔN LÀ khung giờ của phần "active" (length) của chu kỳ hiện tại, kể cả khi thời điểm hiện tại (`now`) thực ra đang nằm trong phần "cooldown" (sau `end`, trước chu kỳ tiếp theo). Comment trong code tự gọi đây là "active/most-recent window" — nghĩa là caller không có cách nào biết được sự kiện có ĐANG active hay không chỉ từ `SeasonEventWindow` một mình; phải tự gọi `nowMsClamped()`/`DateTime.now()` rồi so sánh thủ công với `window.start`/`window.end`, dễ dùng sai đồng hồ (quên dùng `nowMsClamped()`, dùng `DateTime.now()` trực tiếp — phá đúng bất biến "an toàn trước chỉnh giờ" mà cả class này được thiết kế để bảo vệ).

## Vì sao cần / Hậu quả
Không có field/helper này, `CountdownChip` (widget đã note rõ trong doc là "cần caller tự tính bằng tay hôm nay") hoặc bất kỳ UI banner "sự kiện đang diễn ra" nào dùng `SeasonEventService` đều phải tự viết lại đúng phép so sánh thời gian mà service này vốn đã tính bên trong — rủi ro lệch logic, và rủi ro caller lỡ dùng `DateTime.now()` thay vì đồng hồ đã clamp.

## Đề xuất
Thêm 1 field `bool isActive` vào `SeasonEventWindow`, tính đúng ngay tại thời điểm `currentWindow()` tạo ra window đó (dựa trên `now` đã có sẵn trong hàm, không tính lại đồng hồ lần nữa) — `true` nếu `now` nằm trong `[start, end)`, `false` nếu đang ở phần cooldown. Không đổi chữ ký `currentWindow()`, không đổi `start`/`end` hiện có.

## Acceptance criteria
- [x] `isActive == true` khi `now` nằm trong khung `[start, end)` (đang ở phần "length" của chu kỳ).
- [x] `isActive == false` khi `now` nằm sau `end` nhưng trước chu kỳ tiếp theo (đang ở phần "cooldown").
- [x] Gọi lại `currentWindow` nhiều lần trong CÙNG 1 khoảnh khắc active: `isActive` nhất quán `true` mỗi lần, `start`/`end` không đổi (không phá hành vi hiện có).
- [x] `cooldown == Duration.zero` (event active liên tục, không nghỉ): `isActive` luôn `true`.
- [x] Test: unit test đầy đủ mọi case trên, dùng cùng kỹ thuật giả lập thời gian đã có trong test hiện có của `SeasonEventService` (không cần chờ đồng hồ thật).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không có animation mới cần thiết (thay đổi core service/data class thuần).
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-52-season-event-window-is-active.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/season_event_service.dart` và `test/core/season_event_service_test.dart` hiện có để hiểu đúng công thức `cycleIndex`/`startMs`/`elapsed` hiện tại trước khi thêm field. Implement bằng TDD (viết test fail trước, code cho pass) — chú ý: `isActive` phải tính từ CHÍNH `now`/`startMs` đã có sẵn trong `currentWindow()`, không gọi lại `nowMsClamped()` lần thứ 2 (tránh 2 lần đọc đồng hồ trong cùng 1 lần gọi lệch nhau, dù chỉ về lý thuyết).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — chỉ 1 field bool tính đúng 1 lần, không thêm state/side-effect mới).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên wire `isActive` vào demo `CountdownChip`/season event nào đó trong `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android/iOS thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator), chụp screenshot làm bằng chứng, ghi vào `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `season_event_service.dart`: `SeasonEventWindow` chỉ có `start`/`end`, không có field active nào; comment ngay trong docstring của `currentWindow` tự thừa nhận đây là window "active/most-recent", ngầm định caller tự suy ra trạng thái active. Effort nhỏ (1 field bool + phép so sánh đã có sẵn dữ liệu), không đụng file nhạy cảm/scope peer.

## Quyết định

Thêm field `bool isActive` vào `SeasonEventWindow` (constructor giờ yêu cầu đủ 3 tham số), tính ngay trong `currentWindow()` bằng đúng `now`/`startMs` đã có sẵn trong hàm — `isActive: now - startMs < length.inMilliseconds` — không gọi lại `nowMsClamped()` lần thứ 2, đúng yêu cầu tránh đọc đồng hồ 2 lần trong Prompt.

**Bug phát hiện khi viết test (test-only, không phải bug sản phẩm)**: 2 test đầu tiên của tôi vô tình nhảy đồng hồ RỒI MỚI gọi `currentWindow()` lần đầu tiên cho 1 `eventId` mới — nhưng `currentWindow()` tự đặt `anchorMs = now` cho lần gọi đầu tiên (đúng hành vi đã có, không phải bug), nên test "đang cooldown" vô tình luôn active tại chính anchor mới của nó. Sửa lại test: gọi `currentWindow()` 1 lần TRƯỚC để thiết lập anchor, rồi mới nhảy đồng hồ, rồi gọi lại — đúng ý định kiểm tra "đang ở cooldown của 1 anchor đã có từ trước".

**Test:** 6 test mới trong `test/core/season_event_service_test.dart` nhóm "IDEA-52" — active đúng trong `[start, end)`, false đúng khi đang cooldown, nhất quán qua nhiều lần gọi trong cùng khoảnh khắc, `cooldown == Duration.zero` luôn active, đúng biên `start` (inclusive) và `end` (exclusive).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1116/1116 pass. Không đụng `example/` — xác nhận `SeasonEventService`/`SeasonEventWindow` hiện CHƯA được dùng ở đâu trong `example/` (grep rỗng), nên không có demo có sẵn để wire vào; không tạo demo mới (đúng "không bắt buộc" trong Prompt).

**Tự chấm điểm: 9.5/10** — đúng mọi acceptance criteria, tính `isActive` từ đúng 1 lần đọc đồng hồ duy nhất như yêu cầu nghiêm ngặt nhất trong Prompt, phát hiện và tự sửa đúng 1 lỗi trong chính bộ test của mình trước khi kết luận (không phải bug sản phẩm) thay vì bỏ qua. Trừ điểm nhỏ vì thay đổi constructor `SeasonEventWindow` là breaking change về mặt kỹ thuật (thêm required param) — chấp nhận được vì class này chưa hề được dùng ở `example/` hay bất kỳ nơi nào khác ngoài chính service, xác nhận qua `flutter analyze` sạch tuyệt đối sau khi đổi.
