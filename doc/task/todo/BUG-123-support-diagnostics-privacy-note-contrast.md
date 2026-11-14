---
id: BUG-123
title: "SupportDiagnosticsCard privacy note contrast below AA on light card"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text audit, 2026-11-14"
---

## Evidence
The active privacy note uses `NeonTheme.inkSoft` at 12sp on opaque `NeonTheme.card` in light mode. Rendered contrast is 3.92:1, below 4.5:1 for normal text. It is not disabled or suppressed in the visible state.

## Scope
Raise privacy-note contrast to at least 4.5:1 in both themes without changing global theme tokens. Preserve its subordinate visual hierarchy and share-confirmation behavior.

## Acceptance
- Add a rendered-contrast regression test for the privacy note in light/dark modes.
- Light-mode note reaches at least 4.5:1 on its actual opaque card surface.
- Existing widget and golden tests pass.
