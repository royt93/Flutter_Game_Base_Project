---
id: BUG-104
title: "StreakRepairDialog tràn ngang dưới 368dp và bị cắt ở landscape"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "Audit UI 2026-11-12 (cùng loại PauseOverlay/BUG-103)"
---

## Vị trí
`lib/presentation/widgets/common/streak_repair_dialog.dart` (panel `width: 320` + margin 24 hai bên, không cuộn).

## Hiện trạng
Màn 320dp cần 368dp nên tràn ngang; landscape 320dp cao bị cắt nút Skip.

## Đã làm
`ConstrainedBox(maxWidth: 320)` + margin 16 + `SingleChildScrollView`. Test `BUG-104` ở 320x480, 568x320, 640x320 (đỏ trước khi sửa, xanh sau).

## Không làm
Không đổi API, text, màu; không có golden riêng nên không cần regenerate.
