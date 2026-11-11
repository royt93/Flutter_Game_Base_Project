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

- [ ] `lockedBorder` trên `lockedFill` đạt ≥ 3.0:1 ở light và dark.
- [ ] Token có biến thể dark riêng; `NeonTheme.dark` đổi được cả hai.
- [ ] Test `PHÁT HIỆN THẬT` được cập nhật thành test xác nhận đã đạt; validator không còn báo issue `uiComponent`.
- [ ] Golden của 4 widget được tái tạo bằng workflow `regenerate-goldens.yml` (không tạo trên macOS); lockfile không đổi.

## Test plan

- [ ] `flutter test test/core/utils/theme_contrast_validator_test.dart test/widget/common/level_select_grid_test.dart`.
- [ ] `flutter analyze` root; `dart run tool/api_compatibility.dart check` (token là public).
- [ ] Rà `quality-gate`: `dart run tool/accessibility_audit_check.dart`.
- [ ] Kiểm tra thị giác trên thiết bị thật (S24 Ultra, `SM-S928B`) ở light và dark.

## Constraints

- Chỉ code trên `main`, không branch/worktree.
- Không tạo golden trên macOS; theo quy trình `regenerate-goldens.yml` trong `CLAUDE.md`.
