---
id: BUG-129
title: "CommunityLeaderboardCard overflows vertically on short screens"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 phase 2u viewport sweep, 2026-11-15"
---

## Evidence
`CommunityLeaderboardCard` contains a heading and a bounded leaderboard list; together with padding, the card overflowed vertically at 320×480 dp and 568×320 landscape. The viewport sweep found bottom RenderFlex overflow.

## Fix
Wrap the card body in `SingleChildScrollView`, preserving the existing bounded inner leaderboard list so the panel fits shorter viewports while rows remain independently scrollable.

## Verification
- [x] FEAT-200 phase 2u default and 2× text viewports pass.
- [x] Existing `CommunityLeaderboardCard.refreshLabel` test passes.
- [x] Full viewport suite passes 167 tests.
