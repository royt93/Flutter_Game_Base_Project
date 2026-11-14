---
id: BUG-120
title: "StreakRepairDialog subtitle contrast below AA on light card"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text audit, 2026-11-14"
---

## Evidence
The active subtitle uses `NeonTheme.inkSoft` over opaque `NeonTheme.card` in light mode. Rendered contrast is 3.92:1, below 4.5:1 for normal text. The fixture uses the same card surface as the widget; this is not a disabled control.

## Scope
Raise subtitle contrast to at least 4.5:1 in both themes without changing global theme tokens or altering the widget's visual hierarchy. Keep dark mode, localization, and caller-provided subtitle behavior intact.

## Acceptance
- Add a rendered-contrast regression test for `StreakRepairDialog` in light and dark modes.
- Light subtitle is at least 4.5:1 on its actual opaque card surface.
- Existing widget, semantics, and golden tests pass.
