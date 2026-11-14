---
id: BUG-121
title: "PrestigeConfirmationCard secondary text contrast below AA in light mode"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-205 rendered-text audit, 2026-11-14"
---

## Evidence
Active message text uses `NeonTheme.inkSoft` on opaque `NeonTheme.card` (3.92:1); multiplier labels use `inkSoft` on opaque `NeonTheme.cardAlt` (3.40:1) in light mode. Both fall below 4.5:1 for normal text. The warning chip was separately fixed by ENH-104; do not conflate it with these remaining strings.

## Scope
Raise contrast only for the confirmed message and multiplier labels; do not change global theme tokens. Preserve value colors, layout, localization overrides, and dark mode.

## Progress (2026-11-14)
- [x] Changed message and multiplier labels to local `NeonTheme.ink`; value colors remain unchanged.
- [x] Rendered-text assertions pass in light/dark; affected widget tests pass.
- [x] Replaced 14 prestige PNGs from Linux `regenerate-goldens.yml` artifact. Prestige golden suite passes locally against those baselines.

## Acceptance
- [x] Add rendered-contrast assertions for the message and both multiplier labels in light/dark modes.
- [x] Confirmed light-mode text reaches at least 4.5:1 on its actual flat surface.
- [x] Existing non-golden widget tests pass.
- [ ] Existing golden tests pass after approved Linux baseline regeneration.
