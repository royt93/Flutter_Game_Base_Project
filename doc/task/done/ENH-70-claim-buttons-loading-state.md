---
id: ENH-70
title: "DailyLoginCalendarWidget/QuestBoardPanel: nút Claim chưa dùng CommonButton.loading"
type: enhancement
priority: low
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `daily_login_calendar.dart`, `quest_board_panel.dart`, đối chiếu `doc/task/done/IDEA-53-common-button-loading-state.md`/ENH-66/ENH-67)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/daily_login_calendar.dart` (`DailyLoginCalendarWidget`) và `lib/presentation/widgets/common/quest_board_panel.dart` (`QuestViewModel`/`QuestBoardPanel`).

## Hiện trạng
`CommonButton.loading` (IDEA-53) đã được áp dụng cho `ShopItemCard` (ENH-66) và `BackupRestorePanel` (ENH-67) — cả 2 đều là hành động async thật (mua IAP, export/import). 2 chỗ khác trong widget kit cũng có nút "Claim"/"Nhận thưởng" nhưng CHƯA forward `loading`:

- `daily_login_calendar.dart:75`: `CommonButton(label: claimLabel, onTap: canClaimToday ? onClaim : null)` — `onClaim` là `VoidCallback` thuần, không có cách nào caller báo hiệu "đang xử lý claim" (ví dụ claim cần xác nhận với server).
- `quest_board_panel.dart:120-124`: mỗi `_QuestRow` có `CommonButton` riêng cho quest đó, `onTap: quest.isClaimable ? widget.onClaim : null` — không có field nào trên `QuestViewModel` để đánh dấu "quest này đang claim", nên NHIỀU quest hiện có thể bấm claim đồng thời không có tín hiệu nào phân biệt cái nào đang xử lý.

## Vì sao cần / Hậu quả
Cả 2 widget này đều theo convention "pure/data-driven" đã có trong repo (giống `LeaderboardList`) — không tự giữ state async, caller (consumer app) tự quản lý. Nhưng vì thiếu field `loading`/`claiming`, 1 consumer app muốn hiện spinner khi đang chờ server xác nhận claim buộc phải tự custom lại toàn bộ nút (đúng vấn đề IDEA-53 đã giải quyết cho `CommonButton`, nhưng chưa lan tới 2 widget cấp cao hơn này).

## Đề xuất
- `DailyLoginCalendarWidget`: thêm `bool claiming = false` (mặc định `false` = hành vi y hệt hiện tại), forward `loading: claiming` xuống đúng `CommonButton` ở dòng 75.
- `QuestViewModel`: thêm field `bool claiming = false` (mặc định `false`). `_QuestRow`/`QuestBoardPanel` forward `loading: quest.claiming` xuống đúng `CommonButton` của quest đó — CHỈ đúng quest đang `claiming: true` mới hiện spinner, các quest khác không đổi.

Không đổi `onClaim`/`onTap` signature — caller vẫn tự set `claiming: true` trước khi gọi hành động async, rồi `claiming: false` sau khi xong, y hệt cách `_activeAction` được dùng ở ENH-67 nhưng ở tầng NGOÀI widget (đúng convention pure/data-driven).

## Acceptance criteria
- [x] `DailyLoginCalendarWidget(claiming: true)`: nút Claim hiện spinner (qua `CommonButton.loading`), chặn tap. `claiming: false` (mặc định): hành vi y hệt hiện tại.
- [x] `QuestViewModel(claiming: true)` cho 1 quest cụ thể: CHỈ nút Claim của quest đó hiện spinner/bị chặn tap; các quest khác trong cùng `QuestBoardPanel` không bị ảnh hưởng.
- [x] Không đổi hành vi `canClaimToday`/`isClaimable`/`claimed` hiện có — `claiming: true` không ghi đè logic disable đã có (ví dụ quest chưa hoàn thành vẫn không claim được dù `claiming: false`).
- [x] Không phá bất kỳ test nào trong `test/widget/common/daily_login_calendar_test.dart` và `test/widget/common/quest_board_panel_test.dart` (hoặc tên file tương đương — kiểm tra tên chính xác trước khi sửa).
- [x] Test: unit/widget test đầy đủ mọi case trên cho cả 2 widget.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` — nếu muốn minh hoạ, cân nhắc wire vào demo sẵn có trong `widget_showcase_screen.dart` (không bắt buộc, nếu làm phải test + device smoke test).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-70-claim-buttons-loading-state.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `daily_login_calendar.dart`, `quest_board_panel.dart`, và test hiện có của cả 2 (tìm đúng tên file test bằng `find test -iname "*daily_login_calendar*" -o -iname "*quest_board*"`) trước khi sửa. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng convention pure/data-driven đã có, không tự thêm state async vào bên trong widget, không phá API/test hiện có, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria cho CẢ 2 widget.
3. Cân nhắc có nên wire vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android/iOS thật hiện có (kiểm tra `mobile_list_available_devices` FRESH trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator). Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — xác nhận qua đọc trực tiếp `daily_login_calendar.dart:75` và `quest_board_panel.dart:120-124`: cả 2 đúng là chưa forward `loading`. Độ tin cậy không tuyệt đối như ENH-66/67 vì bản thân demo hiện tại của 2 widget này CHƯA có hành động async thật (claim đồng bộ) — nhu cầu là suy luận hợp lý theo đúng pattern đã lặp lại 2 lần trong repo (IDEA-53 → ENH-66 → ENH-67), không phải bằng chứng "đã dùng async nhưng thiếu loading" trực tiếp như 2 task trước. Effort nhỏ, không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

- `DailyLoginCalendarWidget`: thêm `bool claiming = false`, forward `loading: claiming` xuống `CommonButton` (tự chặn tap khi loading — không cần thêm điều kiện thủ công). Riêng ô ngày `_DaySlot` (không phải `CommonButton`, tự vẽ) cần chặn tap thủ công: `onTap: (isCurrent && !claiming) ? onClaim : null` — visual highlight (viền cyan "current") vẫn giữ nguyên khi đang claiming (chỉ chặn tap, không đổi hình thức "current" thành "upcoming").
- `QuestViewModel`: thêm field `bool claiming = false`, forward `loading: quest.claiming` xuống đúng `CommonButton` của quest đó trong `_QuestRow` — mỗi quest độc lập, không có state chung ở tầng `QuestBoardPanel`.

**Test:** 3 test mới cho `DailyLoginCalendarWidget` (`daily_login_calendar_test.dart`) và 4 test mới cho `QuestBoardPanel` (`quest_board_panel_test.dart`), nhóm "ENH-70" ở cả 2 file — truyền đúng xuống `CommonButton`+hiện spinner, chặn đúng tap (cả nút Claim lẫn ô ngày current cho `DailyLoginCalendarWidget`; đúng quest cho `QuestBoardPanel`, quest khác không bị ảnh hưởng), mặc định `false` không đổi hành vi cũ. Toàn bộ 31 test cũ (18 + 13) vẫn pass nguyên vẹn.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1206/1206 pass. Không demo trong `example/` (không bắt buộc — cả 2 demo hiện tại đều claim đồng bộ, không có async thật để minh hoạ ý nghĩa của `claiming`, đúng ghi chú độ tin cậy "trung bình-cao" đã tự nêu trong task).

**Tự chấm điểm: 9.5/10** — đúng convention pure/data-driven đã có (không tự thêm state async vào bên trong widget, caller tự quản lý `claiming`), tái dùng triệt để `CommonButton.loading` đã có, xử lý đúng case tinh tế nhất (ô ngày current của `DailyLoginCalendarWidget` không phải `CommonButton`, cần chặn tap thủ công riêng, và phải giữ nguyên visual "current" khi đang claiming thay vì lẫn với "upcoming"). Trừ điểm nhẹ vì đây là task dựa trên suy luận pattern hợp lý hơn là bằng chứng "đã cần async thật nhưng thiếu" trực tiếp như ENH-66/67.
