---
id: BUG-124
title: "GameOverCardTemplate message contrast below AA on light card"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text audit, 2026-11-14"
---

## Evidence
The active message uses `NeonTheme.inkSoft` at 14sp/600 inside opaque `PanelCard` (`NeonTheme.card`) in light mode. Rendered contrast is 3.92:1, below 4.5:1 for normal text. This finding covers the message, not the stroked title or action-button labels.

## Scope
Raise message contrast to at least 4.5:1 in both themes without changing global theme tokens. Preserve the card's hierarchy and caller-provided message.

## Progress (2026-11-14)
- [x] Changed message to `NeonTheme.ink`; rendered-text assertions pass in light/dark.
- [x] Existing `game_over_card_template_test.dart` passes.

## Acceptance
- [x] Add a rendered-contrast regression test for `GameOverCardTemplate` in light/dark modes.
- [x] Light-mode message reaches at least 4.5:1 on its actual opaque card surface.
- [x] Existing widget tests pass.
- [x] No golden test found for this widget.
