---
id: w4-mode-time-attack
title: Mode — Time Attack
wave: 4
status: done
owner: claude
---

# Game Mode 5 — Time Attack

## Mục tiêu
Đạt điểm mục tiêu trong GIỚI HẠN THỜI GIAN (không giới hạn lượt).

## Thiết kế
- `ObjectiveType.timeAttack` + `LevelConfig.timeLimit` (giây).
- **GameController**:
  - `RxInt timeLeft`.
  - `startLevel` set timeLeft = cfg.timeLimit.
  - `void tickTime(int seconds)` giảm timeLeft (không < 0).
  - `hasWon` (timeAttack) = score ≥ target.
  - `isOutOfMoves` → false khi timeAttack (không tính lượt).
  - `bool get isOutOfTime` = timeAttack && timeLeft ≤ 0.
  - `checkEnd`: thua khi hết thời gian mà chưa đạt điểm.
  - `objectiveProgress` (timeAttack) = score/target.
  - `computeStars` (timeAttack) = theo tỉ lệ điểm (như score).
- **NeonJewelGame.update**: cộng dt, mỗi 1 giây gọi `controller.tickTime(1)`; khi 0 → `_finishMove()`. Chạy kể cả khi _busy, dừng khi _ended.
- **HUD**: khi timeAttack hiện chip TIME (mm:ss) thay cho MOVES, đổi màu đỏ khi ≤10s.

## Acceptance
- [x] tickTime giảm đúng, không âm
- [x] hết giờ chưa đủ điểm → lose; đủ điểm → win
- [x] HUD hiện TIME đúng định dạng
- [x] unit test logic time attack
- [x] analyze 0 issue · test pass

## ✅ Kết quả
Hoàn thành Wave 4 — analyze 0 issue · 89 test pass · build APK debug OK.
