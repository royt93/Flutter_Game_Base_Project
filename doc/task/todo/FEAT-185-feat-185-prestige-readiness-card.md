---
id: FEAT-185
title: PrestigeReadinessCard — Threshold progress and gated CTA
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Privacy, Progression and Cooldown UI (Wave 23)
---

## Phạm vi
- Presentation-only progress toward a prestige threshold with a multiplier line. CTA enabled only when `current >= threshold` and not `busy`; progress bar clamps at 100%.
- The card never prestiges. `onPrestige` should open a confirmation (showcase uses `PrestigeConfirmationCard.show`) before the caller invokes `PrestigeService.prestige`.
- Runtime validation: threshold > 0, current >= 0, non-blank copy.

## Kiểm chứng
- [x] Widget tests: validation, locked/ready/over-threshold/busy, 320dp + 200% RTL.
- [x] Showcase routes the CTA through the confirmation dialog; host test confirms via the dialog button.
- [x] Local golden layout matrix (locked/ready × 7 variants) passes; macOS PNGs removed.
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
- [ ] Reachable-device smoke (not connected, not claimed).

No claim about prestige persistence; the showcase uses in-memory demo coins.
