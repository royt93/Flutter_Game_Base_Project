---
id: w5-spreading-obstacle
title: Obstacle lan tỏa (chocolate/licorice)
wave: 5
group: Chiều sâu gameplay
status: todo
owner: claude
---

## Mục tiêu
Chướng ngại tự nhân lên mỗi lượt nếu không bị chặn (giống chocolate Candy Crush).

## Phạm vi
- `ObstacleType.spread` mới: mỗi lượt KHÔNG có gem kề nó bị clear → lan sang 1 ô kề ngẫu nhiên (theo nguồn xác định, không random thuần).
- Clear gem kề → phá 1 ô spread; objective `clearObstacle` tính cả spread.
- Render lớp spread (màu nâu/tím neon) trong ObstacleLayer.
- Cân bằng winnability: chỉ rải ở 1 vài màn cuối, đảm bảo còn nước đi.

## Acceptance
- Lan đúng khi không chặn; dừng lan khi chặn; không khoá cứng bàn. Test winnability + lan. 0 analyzer issue.
</content>
