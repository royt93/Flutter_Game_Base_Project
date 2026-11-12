---
id: ENH-106
title: "SpotlightOverlay skip link và InventoryGrid slot thiếu tap target/semantics"
type: enhancement
layer: lib/widgets/common
priority: P3
effort: S
source: "Audit a11y 2026-11-12"
---

## Đã làm
- `spotlight_overlay.dart`: skip link cao ~48dp (padding dọc 14), `HitTestBehavior.opaque`, `MergeSemantics` + `Semantics(button: true)`.
- `inventory_grid.dart`: slot có `onTap`/`onLongPress` bọc `Semantics(button: true)`.
Test ENH-106 kiểm chiều cao >= 48 và ancestor `Semantics(button)`.

## Chưa làm (ghi nhận, chưa có bằng chứng lỗi)
- `toggle_switch.dart:50` track cao 30, `segmented_tab_bar.dart:95` tab cao 36: dưới 48dp nhưng có Semantics; cần quyết định thiết kế riêng vì đổi kích thước ảnh hưởng golden.
