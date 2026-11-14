---
id: BUG-125
title: "VipPerkProgressRow secondary labels below AA in light mode"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text probe, 2026-11-14"
---

## Evidence
The active `Next Tier Progress` and `Perks & Privileges` labels use `NeonTheme.inkSoft` on the widget's opaque `NeonTheme.card` surface in light mode. Rendered contrast is 3.92:1, below 4.5:1 for normal text. Both labels are outside gradient decorations and are not disabled. The same labels pass in dark mode.

## Scope
Raise only these two label colors to at least 4.5:1 in both themes without changing global theme tokens. Preserve tier-badge, progress-value, and perk-chip colors.

## Progress (2026-11-14)
- [x] Changed only the two confirmed labels to `NeonTheme.ink`; progress values and perk-chip colors unchanged.
- [x] Rendered-text assertions pass in light/dark; existing VIP widget and viewport tests pass.
- [x] Targeted analyzer clean.

## Acceptance
- [x] Add a rendered-contrast regression test for `VipPerkProgressRow` in light and dark modes.
- [x] Light-mode labels reach at least 4.5:1 on the actual opaque card surface.
- [x] Existing widget and viewport tests pass.
