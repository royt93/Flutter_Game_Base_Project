---
id: BUG-132
title: "Fixed white labels on accent badges and selected tabs fail WCAG AA"
type: bug
layer: lib/presentation/widgets/common
priority: P2
effort: M
source: "Fixed Colors.white/black classification after FEAT-210, 2026-11-18"
---

## Evidence
Read-only classification of `Colors.white|black` in `lib/presentation/widgets/common` found 76 occurrences. Most are borders, scrims, gradient lightening, icon glyphs, spinner/thumb colors or already-fixed fills. Probe of flat badge fixtures in light and dark themes measured fixed white text below 4.5:1:

- `ClanChatPreviewBar` unread count on pink: 2.14:1.
- `QuestProgressPill` claimable count on pink: 2.14:1.
- `IconBadgeButton` badge count on default red: 2.78:1.
- `ComebackBundleCard` badge on accent gold: 1.79:1.
- `DailyOfferStack` offer badge on accent gold: 1.79:1.
- `MilestoneCelebrationDialog` level number on gold: 1.79:1 against the 3.0:1 large-text threshold.

Computed palette check for the selected `SegmentedTabBar` pill: white on default cyan is 2.04:1. The harness measured 1.15:1 because the label sits over an animated pill that the flat-ancestor audit cannot see, so that exact figure is not used as evidence.

## Scope
Use the existing foreground/fill helper pattern for solid fills: preserve each badge/tab fill and choose a readable text foreground, or darken fills only after a design decision. Check caller-supplied accent/badge colors without silently overriding them. Do not change borders, scrims, gradients, icon glyphs or decorative shadows in this task unless a measured text issue appears.

## Not in scope
- `StrokeText`/canvas label rendering fixed in FEAT-210/BUG-130/BUG-131.
- Non-text icon contrast already recorded in FEAT-205.
- Gradient and image backgrounds that the flat-surface audit cannot resolve.

## Acceptance
- Each listed text label reaches 4.5:1, or 3.0:1 only where the text is truly large.
- Fixtures cover light/dark and caller-provided colors where the API accepts them.
- `SegmentedTabBar` is verified with actual rendered pill color, not the ancestor-only audit.
- CHANGELOG records any visual behavior change; golden baselines regenerated through the Linux workflow.

## Progress (2026-11-18)
- [x] Added `NeonTheme.textOnFill(Color)`: black or white by WCAG contrast on the solid fill, at least 4.5:1 for any opaque fill; the fill is unchanged.
- [x] Applied to `ClanChatPreviewBar`, `QuestProgressPill`, `IconBadgeButton` (follows caller `badgeColor`), `ComebackBundleCard`, `DailyOfferStack`, `MilestoneCelebrationDialog` and the selected label of `SegmentedTabBar` (follows `activeColor`).
- [x] Tests: `badge_label_contrast_test.dart` (light/dark, default and dark caller badge color, three pill colors) and `textOnFillTests` over 13 fills. The tab is checked against its real pill color rather than the ancestor-only audit.
- [x] CHANGELOG behavior change; API snapshot gained one line.
- [x] 56 golden baselines regenerated through the Linux workflow (run 44306521767): ClanChatPreviewBar, ComebackBundleCard, DailyOfferStack, QuestProgressPill.
