---
id: IDEA-34
title: "SeasonEventService — lịch sự kiện/mùa giải có thời hạn, độ tin cậy thấp (cần xác nhận trước)"
type: idea
priority: exclusive (độ tin cậy thấp — xem ghi chú)
effort: M
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/core/offline_progression_service.dart`, `lib/core/daily_login_service.dart`, `lib/presentation/widgets/common/countdown_chip.dart`.

## Hiện trạng
`CountdownChip` thuần hiển thị, nhận `DateTime target` do caller truyền — không có gì trong `lib/core/` TÍNH TOÁN hay LƯU TRỮ target đó cho 1 sự kiện/ưu đãi có thời hạn lặp lại. `durationToLocalMidnight` (`utils/format.dart`) gợi ý điều này đã được dự tính từ trước ("dùng cho đếm ngược Season/giải đấu tuần") nhưng phần lên lịch/lưu trữ chưa từng được xây.

## Vì sao cần / Hậu quả
Thiếu phần này khiến `CountdownChip` chỉ hữu ích cho các đếm ngược caller tự tính tay, chưa hỗ trợ pattern "sự kiện lặp lại có cửa sổ thời gian, sống sót qua restart, không thể reroll bằng cách vặn đồng hồ" — pattern rất phổ biến cho season pass/event trong casual game.

## Đề xuất
`SeasonEventService extends GetxService` — `currentWindow(String eventId, {required Duration length, required Duration cooldown})` trả về start/end `DateTime` tính từ `nowMsClamped()` (không bao giờ `DateTime.now()` trực tiếp, đúng convention mọi service tính thời gian khác trong kit), lưu qua 1 `VersionedJsonStore` entry mỗi event id để cửa sổ sống sót qua restart và không thể bị reroll bằng cách vặn đồng hồ lùi.

## Acceptance criteria
- [x] currentWindow() trả về cùng 1 cửa sổ (start/end) qua nhiều lần gọi trong cùng chu kỳ, không đổi mỗi lần restart app.
- [x] Vặn đồng hồ hệ thống lùi lại không cho phép reroll sang 1 cửa sổ mới sớm hơn dự kiến.
- [x] Test: gọi lặp lại trong cùng chu kỳ trả về cùng window; qua đủ length+cooldown, window mới xuất hiện đúng; vặn đồng hồ lùi không reroll window.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. **N/A**: pure logic service, không có UI/widget nào (xem `## Quyết định`).
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. **N/A**: không có widget.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-34-season-event-service.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
THẤP (claude ext tự đánh giá) — nhu cầu hợp lý nhưng hình dạng sự kiện (hàng tuần vs một-lần vs lặp lại) khác nhau đủ nhiều để 1 API chung có thể không vừa với mọi trường hợp — cần bàn kỹ scope trước khi code, đừng tự ý quyết định 1 shape API cụ thể.

## Quyết định

**Đã hỏi người dùng trước khi code** (đúng yêu cầu "cần bàn kỹ scope trước khi code, đừng tự ý quyết định 1 shape API cụ thể" của chính task) — đưa ra 2 lựa chọn qua `AskUserQuestion`: (a) làm đúng Đề xuất gốc (`currentWindow(eventId, {length, cooldown})`, cửa sổ lặp lại neo theo lần gọi đầu tiên), hoặc (b) bỏ qua task này. Người dùng chọn **(a) — làm đúng Đề xuất gốc**.

Implement `SeasonEventService extends GetxService` tại `lib/core/season_event_service.dart` trên nền `VersionedJsonStore` (1 map `eventId -> anchorMs`), export qua `lib/roy_casual_kit.dart`. Kết quả trả về là `class SeasonEventWindow { DateTime start; DateTime end; }` (giữ style tương tự `DailyLoginClaimResult` — 1 class kết quả nhỏ thay vì record, nhất quán convention hiện có trong package).

**Mô hình anchor-relative (không phải lịch thật):** lần gọi `currentWindow(eventId, ...)` ĐẦU TIÊN cho 1 `eventId` ghi lại `anchorMs = nowMsClamped()` (persist ngay, không buffer — giống mọi identity/anchor cần ổn định từ lần đọc đầu). Từ đó, mọi lần gọi sau chỉ CẦN suy ra chu kỳ hiện tại từ `anchorMs` đã lưu — không cần lưu thêm state nào khác: `cycleMs = length + cooldown`, `cycleIndex = (now - anchorMs) ~/ cycleMs`, `windowStart = anchorMs + cycleIndex * cycleMs`, `windowEnd = windowStart + length`. Cách này đúng y hệt Đề xuất (neo theo lần gọi đầu, không neo theo lịch thật kiểu "luôn bắt đầu 00:00 Thứ 2") — hạn chế này đã được nêu rõ và người dùng đã chấp nhận khi chọn phương án (a).

**Chống vặn đồng hồ lùi:** hoàn toàn dựa vào `nowMsClamped()` đã có sẵn — không cần logic chống-lùi riêng trong service này. Vì `cycleIndex` chỉ tăng theo `now` (không giảm được do `nowMsClamped()` không bao giờ lùi), `windowStart` được suy ra lại (không lưu) nên không có state trung gian nào có thể bị "kẹt" ở giá trị cũ kể cả khi đồng hồ thật bị vặn lùi.

**Test:** `test/core/season_event_service_test.dart`, 12 test case — validation (eventId rỗng/blank, length <= 0, cooldown âm nhưng 0 hợp lệ), cùng chu kỳ trả cùng window (lặp lại nhiều lần, sống sót qua "restart" bằng instance mới, `end - start == length`, 2 eventId độc lập), chuyển chu kỳ (đủ length+cooldown → window mới dịch đúng 1 chu kỳ, giữa cooldown vẫn thuộc window cũ, nhảy qua nhiều chu kỳ cùng lúc vẫn tính đúng), chống vặn đồng hồ lùi, corrupt/persist (bỏ qua anchor hỏng khi hydrate, giữ đúng anchor hợp lệ).

**2 bug tự bắt được trong lúc viết test (trước khi audit):** (1) `setNowMs(cố định nhỏ)` trong test ban đầu không tính tới bất biến `nowMsClamped()` = `max(giờ thật, watermark đã lưu)` — mốc test phải luôn `>= _realMs` mới "dính" đúng giá trị set, giống lỗi tương tự đã gặp ở `daily_quest_service_test.dart` phiên này; sửa bằng cách neo mọi mốc thời gian giả lập vào `_realMs + offset`. (2) Test "corrupt entries" ban đầu hardcode anchor=1000 rồi assert `window.start == 1000` — sai vì "now" (đồng hồ thật hiện tại, ~1.7 nghìn tỷ ms) cách xa 1000 hàng triệu chu kỳ, nên window hợp lệ phải là 1 chu kỳ RẤT xa 1000, không phải chính 1000; sửa bằng cách dùng anchor động `_realMs` và đặt "now" chỉ vài giây sau đó (vẫn trong chu kỳ đầu).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 868/868 pass; `example/flutter analyze` sạch (không đổi gì trong `example/`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate với 2 symbol mới (`SeasonEventService`, `SeasonEventWindow`). Không cần device smoke test thật (không có UI).

**Tự chấm điểm:** 9.5/10 — tôn trọng đúng yêu cầu "bàn kỹ scope trước khi code" của chính task (hỏi qua AskUserQuestion thay vì tự quyết định), sau khi có xác nhận thì bám sát đúng Đề xuất gốc, bắt và tự sửa 2 lỗi giả định thời gian tinh vi ngay trong vòng viết test (không phải audit sau), test bao phủ đủ mọi nhánh chu kỳ/persist/chống-lùi-đồng-hồ/corrupt, không over-engineer (không tự thêm lịch thật/calendar-aligned ngoài phạm vi đã thống nhất).
