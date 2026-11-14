---
id: BUG-122
title: "RewardPopup message contrast below AA on light card"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text audit, 2026-11-14"
---

## Evidence
The active message text uses `NeonTheme.inkSoft` on opaque `NeonTheme.card` in light mode. Rendered contrast is 3.92:1, below 4.5:1 for normal text. The widget is rendered in its ordinary visible state.

## Scope
Raise message contrast to at least 4.5:1 in both themes without changing global theme tokens or the reward's visual hierarchy. Preserve message overrides and reduced-motion behavior.

## Progress (2026-11-14)
- [x] Changed message text to `NeonTheme.ink`; rendered-text assertions pass in light/dark.
- [x] Existing `reward_popup_smoke_test.dart` passes.

## Acceptance
- [x] Add a rendered-contrast regression test for `RewardPopup` in light and dark modes.
- [x] Light-mode message reaches at least 4.5:1 on its actual opaque card surface.
- [x] Existing widget tests pass.
- [x] No golden test found for this widget.
