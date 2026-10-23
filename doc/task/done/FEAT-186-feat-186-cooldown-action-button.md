---
id: FEAT-186
title: CooldownActionButton — Button gated by a caller-read cooldown
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Privacy, Progression and Cooldown UI (Wave 23)
---

## Phạm vi
- Button plus `CooldownCountdownChip`. While `remaining > 0` the button is disabled and the chip shows; `onReady` fires once when the countdown ends so the caller re-reads `PersistentCooldownService` and passes `Duration.zero`.
- UI gate only, not an anti-cheat boundary: the caller re-checks the service inside its tap handler.
- Runtime validation: non-blank label, `remaining >= 0`. `busy` blocks taps.

## Kiểm chứng
- [x] Widget tests: validation, ready tap, waiting disables and shows chip, `onReady` once, busy.
- [x] Showcase cooldown cycle (3s) passes in the host test.
- [x] Local golden layout matrix (ready/waiting × 7 variants) passes; macOS PNGs removed.
- [x] 14 Linux + Flutter 3.35.1 PNG baselines imported from regeneration workflow 39895246813; lockfiles untouched.
- [x] Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke verifies ready/waiting gates; tap re-check remains caller-owned.
- [x] Root/example suites, analyzers, API compatibility, 5 quality gates and CI `39895499954` (analyze-test, quality-gate, consumer-smoke) pass on `240092e`.

The waiting golden shows a fixed 5:00 target; the chip uses wall-clock `DateTime.now()`, so the rendered text is the only time-dependent part.
