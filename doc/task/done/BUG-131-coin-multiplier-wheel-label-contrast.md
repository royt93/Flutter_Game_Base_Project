---
id: BUG-131
title: "CoinMultiplierWheel white labels fail WCAG AA on built-in sectors"
type: bug
layer: lib/presentation/widgets/common
priority: P2
effort: S
source: "FEAT-210 renderer-specific contrast audit, 2026-11-17"
---

## Progress (2026-11-17)
- [x] Keep sector palette/mapping unchanged; choose black/white label foreground by exact composited sector/background WCAG contrast for both alpha 1.0 winner and alpha 0.85 non-winner states.
- [x] Tests cover all multiplier branches and both light/dark opaque backgrounds; label contrast >=4.5:1, findings empty. Sector fill colors and alpha unchanged.
- [x] CHANGELOG behavior change added; CoinMultiplierWheel and common widget tests pass.

## Evidence
`CoinMultiplierWheel` paints white multiplier labels over internally selected cyan/lime/gold/orange sectors. Using declared opaque `backgroundColor`, winning fills (alpha 1.0) and non-winning fills (alpha 0.85) composited over that background all measured below 4.5:1. On light background, non-winning ratios for multipliers 2/3/5/10 are 1.85/1.75/1.66/1.84; on dark background they are 2.66/2.52/2.38/2.68. Winning fills improve versus alpha 0.85 but remain below AA. Decorative black shadow is not counted toward contrast.

## Scope
Choose label foreground/sector colors or palette values that meet 4.5:1 for both winning and non-winning states on supported declared backgrounds. Preserve multiplier tier identity and keep painter/audit paint inputs identical.

## Acceptance
- All four built-in multiplier color branches meet 4.5:1 on supported declared backgrounds, both winning and non-winning alpha.
- Tests cover alpha compositing and every multiplier branch.
- No reliance on decorative shadow to meet contrast; behavior change recorded in CHANGELOG.
- Wheel and common widget tests pass.

## Notes
FEAT-210 reports findings only by explicit user choice. Do not adjust palette in FEAT-210; this separate BUG needs its own design decision before changing colors.
