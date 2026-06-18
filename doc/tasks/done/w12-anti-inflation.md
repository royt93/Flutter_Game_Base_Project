---
id: w12-anti-inflation
title: Chống lạm phát xu + cap farm side-mode
wave: 12
status: done
owner: claude
---
# Kinh tế: kiếm 1660/ngày, mua hết trong ~5 ngày + farm side-mode vô hạn
- Cap farm side-mode (Boss/Rhythm/Gravity/ColorRush): thưởng đầy N lần đầu/ngày, sau giảm mạnh (epoch-day keyed).
- Cân lại thưởng Gravity/ColorRush (50 < màn thường → vô dụng).
## Trạng thái — 🟡 in-progress

## ✅ DONE
- `discountSideModeReward`: 3 trận side-mode đầu/ngày full, sau ×0.3 (epoch-day keyed,
  reset trong resetProgress). Áp boss/rhythm/gravity/colorRush/endless.
- Gravity/ColorRush bump 50→75 (3★) cho ngang màn thường.
- Endless thưởng xu theo stage (×8) → endgame loop (trước = 0).
- `coinsEarnedTotal` nay đếm MỌI nguồn addCoins (sửa nợ "lifetime" + cho thành tựu rich).
- Test farm cap (3 full → giảm).
