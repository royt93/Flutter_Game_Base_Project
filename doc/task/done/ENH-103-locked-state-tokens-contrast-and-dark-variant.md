---
id: ENH-103
title: "NeonTheme lockedBorder/lockedFill: tăng tương phản và thêm biến thể dark"
type: enhancement
layer: core/theme
priority: P2
effort: M
source: "Backlog audit review 2026-11-11 (finding đã ghi ở FEAT-68, chưa có task sửa)"
---

## Vị trí

`lib/core/neon_theme.dart:178-179` (`lockedBorder`, `lockedFill`). Nơi dùng:
`level_select_grid.dart:24,31`, `level_path_map_tile.dart:152-153`,
`daily_login_calendar.dart:165-166`, `reward_choice_panel.dart:172-176`,
và phép kiểm tra trong `lib/core/utils/theme_contrast_validator.dart:216-218`.

## Hiện trạng

Hai token là `static Color` hằng số, dùng chung cho light và dark, khác với `card`/`ink`/`bg*`
vốn đổi theo `NeonTheme.dark`. Cặp `lockedBorder (0xFFBFC7D6)` trên
`lockedFill (0xFFEDEAF5)` chỉ đạt **1.43:1**, thấp hơn ngưỡng UI-component WCAG 3.0:1
(đã đo lại 2026-11-11). `FEAT-68` đã ghi nhận lỗi này và khóa bằng test
`PHÁT HIỆN THẬT: lockedBorder/lockedFill ...` trong
`test/core/utils/theme_contrast_validator_test.dart`, nhưng chưa có task sửa.

## Hậu quả

Node/ô bị khóa khó phân biệt với nền ở light theme, và ở dark theme dùng đúng cặp màu sáng
nên lệch tông so với phần còn lại. Ảnh hưởng 4 widget.

## Scope tối thiểu

Đổi hai token thành getter theo `dark` (như `card`/`ink`), chọn màu đạt ≥ 3.0:1 ở cả light và dark,
cập nhật validator và test "PHÁT HIỆN THẬT" cho đúng kỳ vọng mới. Không đổi API public của
widget. Cần quyết định màu (thiết kế) trước khi làm.

## Acceptance criteria

- [x] `lockedBorder` trên `lockedFill` đạt ≥ 3.0:1 ở light và dark (light `0xFF7B8499` / `0xFFEDEAF5` = 3.16:1; dark `0xFF7C86A8` / `0xFF2A2A4A` = 3.82:1; màu do owner chọn 2026-11-11).
- [x] Token có biến thể dark riêng; `NeonTheme.dark` đổi được cả hai (`lockedBorder`/`lockedFill` giờ là getter). `exportPalette` có 4 key `lockedBorder/FillLight/Dark`; `importPalette` vẫn nhận key cũ `lockedBorder`/`lockedFill` cho biến thể light.
- [x] Test `PHÁT HIỆN THẬT` được cập nhật thành test xác nhận đã đạt; validator kiểm tra `locked*` trong vòng lặp light/dark, không còn trạng thái `constant`, và không báo issue `uiComponent`.
- [x] Không cần tái tạo golden: đã kiểm tra, không golden test nào render `LevelSelectGrid`, `LevelPathMapTile`, `DailyLoginCalendarWidget`, `RewardChoicePanel` hay `LevelNodeButton` (0 tham chiếu trong `test/widget/goldens/`), nên không có PNG nào đổi.

## Test plan

- [x] `flutter test test/core/utils/theme_contrast_validator_test.dart test/core/neon_theme_test.dart test/widget/common/level_select_grid_test.dart` pass; thêm 4 test `ENH-103` trong `neon_theme_test.dart`.
- [x] `flutter analyze` root sạch; `dart run tool/api_compatibility.dart check`: unchanged. 3.514 test root không gồm golden pass; `example/` analyze sạch, 442 test pass.
- [x] `quality-gate`: `accessibility_audit_check` không có issue, `deprecation_check` sạch.
- [x] Kiểm tra thị giác trên thiết bị thật (S24 Ultra, `SM-S928B`, 2026-11-11) ở light và dark: màn Daily Rewards, ô ngày 2–7 (bị khóa) có viền xám-xanh đậm tách rõ khỏi nền ở cả hai theme; không dùng simulator.

## Constraints

- Chỉ code trên `main`, không branch/worktree.
- Không tạo golden trên macOS; theo quy trình `regenerate-goldens.yml` trong `CLAUDE.md`.

## Kết quả

`lockedBorder`/`lockedFill` đổi từ field sang getter theo `NeonTheme.dark` (xem `lib/core/neon_theme.dart`); `lib/core/utils/theme_contrast_validator.dart` kiểm tra cặp này cho cả hai theme. Thay đổi API: gán trực tiếp `NeonTheme.lockedBorder = ...` không còn hợp lệ (trước đây là `static Color` có thể gán); reskin dùng `importPalette`. Không có code trong repo gán trực tiếp hai field này. Đã kiểm tra thị giác trên S24U (light và dark, màn Daily Rewards); không đổi cấu hình thiết bị.
