---
id: w4-obstacles
title: Obstacles — Ice / Chain / Stone
wave: 4
status: done
owner: claude
---

# Obstacles: Ice / Chain / Stone

## Mục tiêu
Thêm chướng ngại ngoài jelly → tăng chiều sâu puzzle. Objective mới: dọn sạch obstacle.

## Thiết kế (lớp overlay trên gem, hạn chế đụng gravity/match)
- `ObstacleType { none, ice, chain, stone }`, `LevelConfig.obstacle` + `obstaclePattern` (tái dùng JellyPattern).
- Lưới `obstacle` (int layers) song song với gem (gem bên dưới vẫn nằm trong grid).
- **ice**: gem match BÌNH THƯỜNG; ô bị clear trực tiếp → giảm 1 lớp ice. Không cho người chơi chủ động swap gem còn ice.
- **chain**: gem match bình thường nhưng KHOÁ swap; gỡ khi ô KỀ bị clear.
- **stone**: gem bên dưới KHÔNG match (loại khỏi color grid) + khoá; gỡ khi ô KỀ bị clear; gỡ xong thành gem thường. Vẫn rơi theo trọng lực.
- **GameController**: `obstacleCleared`, `obstacleTotal`, objective `clearObstacle`, hasWon khi dọn sạch.
- **Render**: `ObstacleLayer` (mô phỏng JellyLayer) — ice = băng xanh nứt, chain = xích, stone = đá xám.

## Acceptance
- [x] ice giảm khi clear trực tiếp; chain/stone gỡ khi ô kề clear
- [x] stone không match khi còn lớp; gỡ xong match lại được
- [x] không cho swap gem bị ice/chain/stone khoá
- [x] hasWon khi obstacleCleared ≥ obstacleTotal
- [x] unit test logic clear obstacle
- [x] analyze 0 issue · test pass · verify gameplay

## ✅ Kết quả
Hoàn thành Wave 4 — analyze 0 issue · 89 test pass · build APK debug OK.
