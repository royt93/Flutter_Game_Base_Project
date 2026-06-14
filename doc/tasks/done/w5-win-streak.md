---
id: w5-win-streak
title: Win Streak / Sweet Streak
wave: 5
group: Meta giữ chân
status: todo
owner: claude
---

## Mục tiêu
Thắng liên tiếp → xu thưởng tăng dần (reset khi thua), tạo động lực chơi liền mạch.

## Phạm vi
- `GameController`: `winStreak` (RxInt) + persist (StorageKeys.winStreak).
- Thắng → streak++, bonus xu = `min(streak, cap) * step` cộng vào lastCoinReward.
- Thua → streak = 0.
- Dialog thắng hiện "STREAK xN +bonus" khi streak ≥ 2.
- i18n.

## Acceptance
- Unit test: streak tăng/giảm + bonus đúng.
- 0 analyzer issue.
</content>
