---
id: w12-wave11-fixes
title: Bù lỗi Wave 11 + hiệu năng
wave: 12
status: done
owner: claude
---
# Correctness + perf (audit Wave 12)
- [HIGH] "1 lượt = 1 tick": truyền consumed vào _finishMove (dispenser/bom/colorRush không tick khi dùng booster).
- [MED] Điểm ô đối tác cổng (expandPortals trước addScore).
- [HIGH perf] GemComponent cache Path + RadialGradient shader (64 shader-alloc/frame → 1 lần/gem).
- [MED perf] BombLayer/DispenserLayer cache TextPainter theo n; _spawnBurst cap particle.
## Trạng thái — 🟡 in-progress

## ✅ DONE
- "1 lượt = 1 tick": `_finishMove(consumed)` → booster không tick dispenser/bom/colorRush.
- Điểm ô cổng: expandPortals trước addScore trong _resolveAll.
- Perf: GemComponent cache Path+RadialGradient shader (64 alloc/frame → 1/gem);
  BombLayer/DispenserLayer cache TextPainter theo số (_NumTextCache).
