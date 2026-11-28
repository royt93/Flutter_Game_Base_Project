# Host line coverage baseline

Updated 2026-11-28 after ENH-128 test additions.

Command:

```bash
flutter test --coverage --exclude-tags slow \
  test/core test/widget/common test/widget/pressable_scale_test.dart \
  test/widget/neon_dialog_test.dart test/tool test/presentation
```

This host suite intentionally excludes `example/`, `test/widget/goldens/`, and
other `test/widget/*.dart` files except `pressable_scale_test.dart`; it includes
`neon_dialog_test.dart` because it directly covers the core overlay API. Line
coverage is a navigation aid, not a correctness score; uncovered lines need a
separate reason or behavior test. No CI coverage gate was added.

| Scope | Covered / total | Line coverage |
| --- | ---: | ---: |
| All measured `lib/` files | 21,550 / 22,112 | 97.46% |
| `lib/core/` | 6,562 / 6,699 | 97.95% |
| `lib/presentation/widgets/common/` | 14,482 / 14,883 | 97.31% |
| Other `lib/presentation/widgets/` | 245 / 248 | 98.79% |
| `lib/presentation/game/` | 261 / 282 | 92.55% |

Change from the previous 2026-11-23 measurement: 97.0% (21,272 / 21,941,
280 files) → 97.46% (21,550 / 22,112, 283 files) with the explicit test scope
above. The target-file snapshots below are from this same final run.

Nine ENH-128 target files (threshold: at least 90%):

| File | Covered / total | Line coverage | Remaining rationale |
| --- | ---: | ---: | --- |
| `scratch_card.dart` | 169 / 169 | 100.0% | All executable lines hit; two optional callbacks (`onThresholdReached`, `onRevealed`) are exercised through the existing reveal test. A brush-width painter mutation survived, so output sensitivity for that setter is not claimed. |
| `pressable_scale.dart` | 51 / 51 | 100.0% | — |
| `neon_dialog.dart` | 115 / 115 | 100.0% | — |
| `card_flip_3d.dart` | 142 / 143 | 99.3% | Line 329 is `shouldRepaint`'s false branch; current public test paths repaint when rotation/progress changes. |
| `golden_shimmer_text.dart` | 98 / 101 | 97.0% | Lines 13, 77–78 are constructor delegation and the invalid-duration throw; invalid duration is already tested at the public constructor and State’s invalid-init teardown is framework-owned. |
| `staggered_animated_grid.dart` | 81 / 86 | 94.2% | Lines 168–172 are the delay-timer replacement path. A test updates the delay before the first entrance, but a mutation that disables replacement survived; execution is covered, behavior is not mutation-verified. |
| `pooled_particle_burst.dart` | 104 / 114 | 91.2% | Lines 71, 78–84 are status/reduced-motion pool callback branches; lines 228, 230 are private painter comparison branches. Constructor validation is covered. The empty-color list is not tested: it violates the widget’s required palette assumption and throws from `Random.nextInt(0)`. |
| `offline_earnings_popup.dart` | 113 / 121 | 93.4% | Lines 182–189 are the alternative reduced-motion/non-reduced count-update paths; message rendering lines are conditionally excluded when the default title and no message are used. |
| `roy_game.dart` | 149 / 163 | 91.4% | Lines 100, 111–127 are Tiled map asset loading and collider conversion; this requires a real Tiled asset fixture and was not added just to raise coverage. |

Other ENH-128 actions: added loader/character tests using an in-memory `ui.Image`
for `RoyGame`; added targeted semantics, lifecycle, animation, validation and
pointer tests for the low-coverage widgets. Three mutation probes were run:
`RoyGame` dropping loaded sprites, `CardFlip3DController.flipToBack()` not
notifying, and `NeonDialog.overlay` no longer blocking semantics — all three
mutants were killed. `StaggeredAnimatedGrid`'s timer-replacement and
`ScratchCard`'s brush-width repaint mutants survived; tests execute those paths
but do not prove those specific outcomes, so they are not claimed as
mutation-verified. `ScratchCard`'s private painter clear lines and
Flame's asset-driven Tiled loading remain outside useful direct coverage. The
final scoped suite had 4,294 passing tests; the ENH-128 final-gate command (which
does not include `pressable_scale_test.dart` or `neon_dialog_test.dart`, measured
separately in the coverage command) had 4,261 passing tests.

No CI coverage gate added.
