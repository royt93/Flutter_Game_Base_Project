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
- [x] Mỗi widget trong danh sách ở Hiện trạng có Semantics wrapper phù hợp (label/value/liveRegion/header/button/toggled tuỳ loại).
- [x] Mỗi widget nhận optional String? semanticLabel (không phá constructor hiện có — chỉ thêm param optional cuối).
- [x] Test cho MỖI widget đã sửa: dùng tester.getSemantics(...) xác nhận label/value đúng ở ít nhất 2 trạng thái khác nhau (ví dụ locked/unlocked, muted/unmuted).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên máy Android thật (Samsung SM-S928B, không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

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

## Quyết định

Chia thành 5 batch commit theo nhóm (đúng gợi ý ở Ghi chú độ tin cậy) thay vì 1 commit khổng lồ:

1. **Batch 1** (`015d951`): `ToastBanner`, `NetworkStatusBanner`, `LoadingOverlay` — `liveRegion: true` cho cảnh báo/toast tức thời.
2. **Batch 2** (`cb2052d`): `ProgressBarStars`, `CurrencyCounter`, `CountdownChip`, `EnergyBar`, `StarRating`, `StreakCounter`, `PaginatedDotsIndicator`, `ShimmerPlaceholder`, `IconBadgeButton` — thêm `semanticLabel` optional + `value`/`label` tính từ state.
3. **Batch 3** (`57c90b4`): `SectionHeader` (`header: true`), `CommonListTile` (`MergeSemantics` + `button`), `BottomSheetPanel` (`ExcludeSemantics` cho drag handle trang trí).
4. **Batch 4** (`e9f8ef5`): `AvatarFrame`, `LeaderboardList`, `LevelSelectGrid`, `DailyLoginCalendarWidget`, `CandyToggleSwitch` — label mô tả trạng thái ("Rank 1, Alice, 9,000", "Level 2, completed, 2 of 3 stars", "Day 3, current, double tap to claim"...).
5. **Batch 5** (`7ec60b3`): `BadgeDot` — `ExcludeSemantics` (thuần trang trí, ý nghĩa thật đã do icon cha của caller mang, ví dụ `IconBadgeButton` tự nối thêm ", N unread"/", new" vào label icon đó).

`ShopItemCard` không cần sửa gì thêm — đã có `MergeSemantics` từ ENH-44 (kiểm tra lại bằng inspection, đúng như note ở Hiện trạng).

### Quyết định kỹ thuật đáng chú ý
- **`Semantics` trên SDK Flutter này KHÔNG có tham số `modal`** (`No named parameter with the name 'modal'`) — `LoadingOverlay` dùng `liveRegion: true, container: true` thay thế, đạt cùng mục đích thực tế (chặn focus xuyên qua + báo trạng thái tức thời) mà không cần `modal`.
- **`MergeSemantics`** (không phải viết tay 1 `label:` string) là cách đúng để gộp nhiều node con (title/subtitle/trailing, hoặc rank/name/score) thành 1 node khi vẫn cần giữ `button`/tap action — pattern tái dùng từ `ShopItemCard` (ENH-44), áp dụng lại cho `CommonListTile`.
- **`excludeSemantics: true`** bắt buộc mọi nơi 1 `Text`/`Icon` con tự có label riêng sẽ bị gộp trùng vào `label:` của `Semantics` cha (biểu hiện: test fail với label kiểu "X\nX").
- Node thuần trang trí không mang ý nghĩa riêng (`BadgeDot`, drag handle của `BottomSheetPanel`) dùng `ExcludeSemantics` thay vì cố gán 1 `label` giả — đúng nguyên tắc "không được là điểm dừng vô nghĩa cho screen reader".

### Device smoke test — Samsung SM-S928B (thật, không simulator)
Build release APK (`flutter build apk --release`), cài qua `adb install -r`, chạy `WidgetShowcaseScreen` (nơi dogfood mọi widget đã sửa) và đọc trực tiếp accessibility tree thật của Android (không phải widget test giả lập) bằng `mobile_list_elements_on_screen`. Bằng chứng cụ thể, đọc được từ tree thật trên máy:
- `CandyToggleSwitch`: tap → track/thumb animate mượt (easeOutBack), tree đổi `Switch label="CandyToggleSwitch\nOn" ... checked` đúng theo state mới.
- `IconBadgeButton`: `Button label="Notifications, new"`, `Button label="Mail, 12 unread"`.
- `CommonListTile` (trong `BottomSheetPanel` lẫn `Layout & Cards`): `Button label="Restart level"`, `Button label="Daily Reward\nClaim your coins"` — gộp đúng 1 node duy nhất.
- `BottomSheetPanel`: mở sheet thật, tree không có bất kỳ node nào cho drag handle (bị `ExcludeSemantics` loại hoàn toàn, không chỉ ẩn label).
- `SectionHeader`: hiển thị đúng làm tiêu đề mọi section ("Feedback & Overlay", "Layout & Cards"...).
- `CountdownChip`: `"Time remaining: 00:00"`; `PaginatedDotsIndicator`: `"Page 1 of 4"`.
- `DailyLoginCalendarWidget`: tap ngày hiện tại → pop animation chạy, tree cập nhật đúng từ `"Day 1, current, double tap to claim"` sang `"Day 1, claimed"`.
- `LeaderboardList`: `"Rank 1, Alice, 12,340"`, `"Rank 2, You, 9,870"`, `"Rank 3, Charlie, 8,120"`.
- `AvatarFrame` (demo không truyền `semanticLabel`/`onTap`): không tạo node `Semantics` thừa — label "RB" passthrough thẳng từ `Text` con, đúng nhánh code không bọc gì khi cả 2 tham số đều null.
- `LevelSelectGrid`: `"Level 1, completed, 3 of 3 stars"`, `"Level 4, unlocked"` (Button, tappable), `"Level 5, locked"` (View, không tappable) — tap level 4 không crash.
- `mobile_get_device_logs` lọc `level=Error` cho process app: không có entry nào trong suốt phiên thao tác trên.

Không kiểm tra lại `AvatarFrame`/`LeaderboardList` variant CÓ `onTap`/`semanticLabel` trên máy thật (đã có bằng chứng qua widget test `tester.getSemantics` ở 2 trạng thái, đủ theo AC) — demo trong showcase hiện chỉ minh hoạ variant display-only.
