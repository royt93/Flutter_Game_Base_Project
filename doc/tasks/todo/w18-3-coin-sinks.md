---
id: w18-3-coin-sinks
title: Thêm coin-sink (cân bằng kinh tế faucet-heavy)
wave: 18
phase: 3
status: todo
owner: claude
---

# Phase 3 — Thêm điểm TIÊU xu (chống lạm phát)

## Vấn đề hiện tại (audit)
Kinh tế lệch mạnh về **faucet** (phát xu):
- BƠM xu/booster: Daily reward, Lucky wheel, Battle Pass, Season, Album, Heo đất,
  Giải đấu, Thành tựu, thắng màn.
- TIÊU xu (sink): CHỈ Đền Neon + Cửa hàng.
→ Cuối game xu dư thừa, mọi reward mất giá trị.

## Thiết kế mới — thêm sink CÓ Ý NGHĨA (chọn 1-2, không p2w mạnh)
1. **Nâng cấp booster vĩnh viễn** (sink chính): tiêu xu nâng cấp 1 lần/booster (vd
   Hammer phá 2 ô; +Lượt thành +15) — đắt dần, giá trị lâu dài.
2. **Craft skin/theme** (gộp với Shop): skin xịn cần "mảnh" mua bằng xu → sink lớn.
3. **Vé chơi mode phụ** (nhẹ): 1 số mode phụ tốn vé (mua bằng xu) sau N lượt free/ngày →
   sink + tạo nhịp. ⚠️ cân nhắc kỹ, dễ gây khó chịu.
4. **Re-roll Daily mutator / pre-game board** bằng xu (sink nhỏ, tiện ích).

## Triển khai
- `game_controller` economy: helper `spendCoins` đã có (theo [[currency-persistence-convention]]).
- Nơi đặt: mở rộng Shop (craft) + màn booster-upgrade mới (hoặc gắn vào Cửa hàng).
- Const giá + đường cong (đắt dần) để hút xu dư mà không chặn người mới.

## Test
- `spendCoins` trừ đúng, clamp ≥0, không âm; nâng cấp persist + áp đúng (Hammer phá 2 ô…).
- Re-roll/craft trừ xu đúng; `resetProgress` đưa về mặc định.
- Cân bằng: chạy ước lượng faucet vs sink (có thể mở rộng `tool/playtest.dart` log coinsEarned).

## Lưu ý
- KHÔNG biến thành p2w nặng (offline, công bằng). Booster-upgrade là QoL, không phá
  leaderboard (leaderboard bot tất định).
- Liên quan: [[balance-economy-principles]], [[currency-persistence-convention]].
