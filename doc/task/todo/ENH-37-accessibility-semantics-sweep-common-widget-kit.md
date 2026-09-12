---
id: ENH-37
title: "Sweep bổ sung Semantics label/role cho ~15 widget trong common/ kit đang thiếu hoàn toàn"
type: enhancement
priority: P2
effort: L
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
Nhiều file trong `lib/presentation/widgets/common/`: `progress_bar_stars.dart`, `toast_banner.dart` (thiếu `liveRegion`), `loading_overlay.dart` (thiếu `modal`), `network_status_banner.dart` (thiếu `liveRegion`), `shimmer_placeholder.dart`, `currency_counter.dart`, `countdown_chip.dart`, `daily_login_calendar.dart` (mỗi `_DaySlot`), `energy_bar.dart`, `star_rating.dart`, `section_header.dart` (thiếu `header: true`), `shop_item_card.dart` (thiếu semantics gộp), `avatar_frame.dart`, `badge_dot.dart`, `streak_counter.dart`, `toggle_switch.dart` (thiếu `label`), `leaderboard_list.dart`, `level_select_grid.dart` (mỗi `LevelNodeButton`), `bottom_sheet_panel.dart`/`list_tile_row.dart`, `paginated_dots_indicator.dart`.

## Hiện trạng
Toàn bộ danh sách trên hiện KHÔNG có `Semantics` wrapper hoặc thiếu `label`/`liveRegion`/`header`/`value` phù hợp — TalkBack/VoiceOver không đọc được nội dung/trạng thái của các widget này. Đây là 1 điểm mù accessibility lớn của cả widget kit, không phải lỗi ở 1 chỗ riêng lẻ mà là mẫu số chung thiếu nhất quán trên diện rộng.

## Vì sao cần / Hậu quả
Người chơi dùng TalkBack/VoiceOver (khiếm thị hoặc hạn chế thị lực) không thể dùng được phần lớn tính năng game xây trên kit này — vi phạm accessibility ở mức cơ bản nhất, và là rủi ro compliance thật ở nhiều store/thị trường yêu cầu accessibility tối thiểu.

## Đề xuất
1 vòng sweep MỘT LẦN qua toàn bộ danh sách, thêm đúng cấu trúc `Semantics` cho từng widget (label mô tả đúng nội dung/trạng thái hiện tại, `liveRegion: true` cho toast/banner cảnh báo tức thời, `header: true` cho `SectionHeader`, `button`/`enabled`/`toggled` cho control tương tác, `value` cho progress/counter). Mỗi widget nhận thêm 1 tham số optional `String? semanticLabel` (nếu chưa có) để caller override khi cần, mặc định fallback về 1 label hợp lý tính từ state hiện tại của chính widget đó — không đổi API bắt buộc nào, chỉ thêm optional.

## Acceptance criteria
- [ ] Mỗi widget trong danh sách ở Hiện trạng có Semantics wrapper phù hợp (label/value/liveRegion/header/button/toggled tuỳ loại).
- [ ] Mỗi widget nhận optional String? semanticLabel (không phá constructor hiện có — chỉ thêm param optional cuối).
- [ ] Test cho MỖI widget đã sửa: dùng tester.getSemantics(...) xác nhận label/value đúng ở ít nhất 2 trạng thái khác nhau (ví dụ locked/unlocked, muted/unmuted).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-37-accessibility-semantics-sweep-common-widget-kit.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao (P2) vì đây là accessibility gap thật trên diện rộng toàn bộ kit — nhưng effort L vì chạm ~15-20 file, nên cân nhắc chia nhỏ thành nhiều PR/commit theo nhóm nếu làm thật (ví dụ theo category Buttons/Feedback/Progress/Layout) thay vì 1 commit khổng lồ, dù vẫn là 1 task/1 file backlog duy nhất.
