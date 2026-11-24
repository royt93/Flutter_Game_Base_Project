---
id: ENH-122
title: "Golden test đợt E: Level / bảng xếp hạng / danh sách (13 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P4
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **E**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (13)

- `level_path_map_tile`
- `level_select_grid`
- `inventory_grid`
- `leaderboard_list`
- `quest_board_panel`
- `booster_slot_bar`
- `stacked_avatar_group`
- `staggered_animated_grid`
- `game_over_card_template`
- `victory_card_template`
- `save_health_card`
- `backup_restore_panel`
- `swipeable_action_tile`

## Lưu ý riêng của đợt
`staggered_animated_grid` animate khi vào: chụp sau khi hoạt ảnh xong.

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [x] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (13 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
- [x] 3. Chạy cục bộ để kiểm test dựng được và không có ngoại lệ khác ngoài "thiếu golden": `flutter test test/widget/goldens/<file>`. KHÔNG commit PNG nào sinh từ máy local (macOS).
- [x] 4. Commit + push các file test (CI `analyze-test` sẽ đỏ tới khi có baseline: đúng quy trình trong CLAUDE.md).
- [x] 5. Chạy `gh workflow run regenerate-goldens.yml --ref main`, chờ xong, tải artifact: `gh run download <run-id> -n regenerated-goldens -D /tmp/goldens-<đợt>`.
- [x] 6. Chép CHỈ các PNG của widget trong đợt vào `test/widget/goldens/goldens/` (lọc theo tiền tố tên); đếm: số PNG chép = số widget × số biến thể đã chốt ở bước 1; `git status` chỉ có PNG mới của đợt, `cmp` xác nhận không PNG cũ nào đổi.
- [x] 7. Kiểm ổn định: chạy workflow lần 2, so hai artifact cho đúng các PNG của đợt (byte-identical hoặc trong tolerance). Widget nào không ổn định: loại khỏi golden, thay bằng test hành vi, ghi lý do.
- [x] 8. Commit + push PNG; xác nhận `analyze-test` xanh. Ghi kích thước thư mục goldens trước/sau (`du -sh`), và kết quả vào "Kết quả thực hiện"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Mỗi widget trong đợt có golden test và PNG cho các biến thể đã chốt (hoặc có lý do ghi rõ khi loại).
- [x] Không PNG ngoài đợt bị đổi.
- [x] Hai lần chạy workflow cho ảnh giống nhau (hoặc trong tolerance 1%).
- [x] Tất cả đều sinh từ Linux workflow, không từ macOS.
- [x] `analyze-test` xanh sau khi chép baseline.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/goldens (trên Linux/CI; trên macOS sẽ đỏ theo thiết kế)`
- `gh workflow run regenerate-goldens.yml --ref main`

## Kết quả thực hiện (2026-11-24)

- Test: `test/widget/goldens/batch_e_level_list_widgets_golden_test.dart`, 14 test (`QuestBoardPanel` có thêm ảnh rỗng), 14 tên golden x 7 biến thể (baseline, dark, locale-vi, rtl, textScale 1.3 và 2.0, reducedMotion) = 98 PNG, 390x760. Phủ đủ 13/13 widget của đợt.
- Baseline: workflow Linux `45423106569`, chép CHỈ 98 file của đợt, từ chối ghi đè, 0 PNG cũ đổi, không PNG nào từ macOS. Thư mục goldens 19M -> 20M.
- Ổn định (bước 7): lần 2 `45423769364`, so từng byte: 98/98 giống hệt.
- Đã xem tận mắt: `staggeredanimatedgrid_done_baseline`, `gameovercardtemplate_states_baseline`, `victorycardtemplate_states_baseline`, `leaderboardlist_states_textScale-2.0`, `swipeableactiontile_closed_baseline`, `boosterslotbar_states_baseline`, `inventorygrid_states_rtl`.

### Bài học: golden rỗng vẫn "pass" (phát hiện nhờ đếm màu từng ảnh)

Hai golden ban đầu sinh ra ảnh MỘT màu (hoàn toàn trống) nhưng test vẫn xanh, vì `matchesGoldenFile` chỉ so ảnh với chính nó:

- `StaggeredAnimatedGrid` (opacity 0 ở mọi ô) và `GameOverCardTemplate` (7/7 ảnh trống): hoạt ảnh vào có `Timer`/`TweenAnimationBuilder` chỉ bắt đầu chạy ở frame SAU lần `pump()` đầu tiên của harness, nên một `pump(1s)` đơn lẻ không đủ. Sửa: `afterPump` bơm nhiều bước ngắn (4 x 100ms, 6 x 200ms cho `VictoryCardTemplate`, 5 x 100ms cho game over).
- Cách phát hiện: script đếm số màu khác nhau trong từng PNG (ngưỡng <= 12 màu). Giờ không ảnh nào trong đợt E còn dưới 6 màu; `swipeableactiontile_closed_*` (6-8 màu) là đúng: trạng thái đóng chỉ có một dòng chữ.

### Hai điểm nghi ngờ đã điều tra và loại trừ (do tôi đọc ảnh sai, không phải lỗi widget)

- `inventorygrid_states_rtl`: lúc đầu tôi nghĩ lưới không đảo chiều. Sai: thứ tự đã đảo đúng (ô trống ngoài cùng bên trái, `potion` ngoài cùng bên phải, ô `sword` được chọn là ô thứ hai từ phải). Probe đầu của tôi sai vì bọc `Directionality` ngoài `MaterialApp`, mà `MaterialApp` đặt lại `Directionality` theo locale.
- `boosterslotbar_states_baseline`: "hộp trắng đè lên biểu tượng" ở ô cooldown là chữ `300s` màu trắng của lớp cooldown (`booster_slot_bar.dart`, `Colors.white`); font test vẽ mỗi ký tự thành ô đặc nên chữ trắng thành khối trắng. Không phải lỗi bố cục.

### Sửa fixture (không sửa widget) và không phủ có chủ đích

- `SwipeableActionTile`: chỉ chụp trạng thái ĐÓNG (mở cần kéo; test hành vi đã phủ).
- `BackupRestorePanel`: chỉ chụp trạng thái rỗi (không chụp đang export/import).
- `LevelPathMapTile` với `isCurrent: true` BẬT pulse lặp (`_shouldPulse = isCurrent && !isLocked`), nên ở 6 biến thể có chuyển động ảnh chụp là khung đầu của vòng pulse (`pump()` một lần, giờ chạy 0), còn biến thể `reducedMotion` chụp trạng thái tĩnh. Hai lần chạy Linux giống từng byte nên khung đó xác định, nhưng ảnh KHÔNG đại diện cho "giữa vòng pulse"; nếu pulse đổi thời lượng hoặc pha, golden này đổi theo.

### Phát hiện ngoài đợt (chưa xử lý)

Phép đếm màu trên toàn bộ 1829 PNG đã commit cho thấy hai nhóm gần như rỗng từ trước: `wave24_battery_off_*` (7 ảnh, 1 màu: `BatterySaverIndicator(active: false)` có thể vẽ rỗng đúng thiết kế) và `avatar_frame_selector_empty_*` (7 ảnh, 5-7 màu: trạng thái "empty"). Chưa điều tra có phải golden "đánh lừa" hay đúng thiết kế.
