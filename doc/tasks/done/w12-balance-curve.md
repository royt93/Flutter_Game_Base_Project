---
id: w12-balance-curve
title: Cân bằng đường cong độ khó
wave: 12
status: done
owner: claude
---
# Sửa tường độ khó bất khả thi (audit Wave 12)
Vấn đề: target tuyến tính + moves co → L43+ score cần 500-1231đ/lượt, L74+ collect 3-4.2 gem/lượt (bất khả thi).
- Score: target = base_moves × perMove(index) (perMove ramp 45→105) thay vì 1000+index*220.
- Collect: collectTarget clamp theo moves (~1.2/lượt) thay 14+index//2.
- TimeAttack: target = timeLimit × perSec(index) thay 900+index*160.
- Test regression: target/moves ratio trong ngưỡng khả thi (chống tái phát tường).
## Trạng thái — 🟡 in-progress

## ✅ DONE
- `_scoreTarget/_timeTarget/_collectTarget` gắn target với LƯỢT (score 45→100đ/lượt,
  collect ≤1.2/lượt, time 36→60đ/giây) thay target tuyến tính bất khả thi.
- Test regression `levels_test`: target ≤ moves×110 (score) / moves×1.5 (collect) /
  timeLimit×75 (time) → chống tường tái phát.
