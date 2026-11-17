---
id: BUG-126
title: "FriendRequestTile overflows in compact landscape at 2x text"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 phase 2m viewport sweep, 2026-11-14"
---

## Evidence
At 568×320 dp and 2.0× text scale, `FriendRequestTile` stacked both action buttons vertically and overflowed the bottom by 15 px. The widget already keeps actions side-by-side by default and stacks them only for large text.

## Fix
Keep actions side-by-side when landscape width is at least 480 dp; retain stacked layout at narrower widths.

## Verification
- [x] Added this viewport to FEAT-200 sweep; phase 2m now passes.
- [x] Existing `friend_request_tile_test.dart` passes.
- [x] Full viewport sweep passes 126/126; targeted analyzer clean.
