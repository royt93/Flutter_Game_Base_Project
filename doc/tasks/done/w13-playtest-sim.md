---
id: w13-playtest-sim
title: Auto-playtest simulator (validate cân bằng)
wave: 13
status: done
owner: claude
---
# Bot headless Monte Carlo validate đường cong Wave 12
- Mô phỏng score/collect/timeAttack bằng MatchDetector + bot greedy.
- Báo pass-rate, lượt TB, điểm TB mỗi màn → flag màn quá dễ/khó.
## Trạng thái — 🟡 in-progress

## ✅ DONE
- tool/playtest.dart: bot greedy Monte Carlo + mô hình special (match-4 nổ hàng+cột,
  match-5 xoá màu) chơi mỗi màn 120 lần, báo pass-rate/điểm TB.
- PHÁT HIỆN: curve Wave 12 vẫn để TimeAttack ~0% + late-game gắt → TINH CHỈNH:
  scorePerMove 42→82 (was 45→105), timePerSec 22→34 (was 35→60), collect cap ~1/lượt,
  moves sàn 15→17.
- KẾT QUẢ: 0 màn "quá khó" (đều ≥58% với bot không-booster → người chơi cao hơn).
