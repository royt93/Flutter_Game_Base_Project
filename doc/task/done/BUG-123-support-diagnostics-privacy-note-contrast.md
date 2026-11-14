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

## Progress (2026-11-14)
- [x] Changed privacy note to `NeonTheme.ink`; rendered-text assertions pass in light/dark.
- [x] Existing `support_diagnostics_card_test.dart` passes.
- [x] Replaced 21 support diagnostics PNGs from Linux `regenerate-goldens.yml` artifact. Local macOS golden comparison differs by host rendering; full Linux CI passes on `3677a300`.

## Acceptance
- [x] Add a rendered-contrast regression test for the privacy note in light/dark modes.
- [x] Light-mode note reaches at least 4.5:1 on its actual opaque card surface.
- [x] Existing non-golden widget tests pass.
- [x] Existing support diagnostics goldens pass in Linux CI on `3677a300`.
