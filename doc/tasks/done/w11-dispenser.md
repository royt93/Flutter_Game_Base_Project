---
id: w11-dispenser
title: Ô phát special (Dispenser)
wave: 11
status: done
owner: claude
---

# Dispenser — ô nguồn phát gem special định kỳ

Ô cố định trên bàn, mỗi N lượt phát 1 gem special (striped/bomb) hoặc lucky xuống
cột của nó → điểm tựa chiến thuật. Weave vào màn khó.

## Việc
- `kDispenserLevels` + vị trí ô dispenser theo màn.
- Engine: mỗi N lượt, ô dispenser sinh 1 special vào ô trống gần nó (hoặc đỉnh cột).
- HUD badge. Render ô dispenser (lõi phát sáng + đếm lượt tới phát).
- i18n en+vi. Guide.

## Test
- phát đúng chu kỳ; gem phát ra là special; không phá winnability.

## Trạng thái — 🟡 in-progress
 → ✅ DONE
- `kDispenserSpec` {13,19} (ô + chu kỳ). Engine `_tickDispensers()` mỗi N lượt → biến gem thường tại ô nguồn thành special (striped/bomb).
- `dispenserCountdown` Rx cho HUD; `DispenserLayer` lõi sáng + số đếm. HUD badge. i18n.
- Test: spec là score, rời nhau (gộp test chung).
