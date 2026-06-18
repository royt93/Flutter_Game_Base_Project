---
id: w14-obstacle-licorice-jam
title: Obstacle mới — Licorice lock + Jam lan
wave: 14
status: done
owner: claude
---

# Obstacle: Licorice (khoá 2 lớp) + Jam (lan rộng)

Mở rộng `ObstacleType` (đang có none/ice/chain/stone/spread):
- **licorice**: khoá swap, cần clear ô kề 2 lần để gỡ (2 lớp). Loại khỏi match.
- **jam (mứt)**: lan như spread nhưng khác chất — mỗi lượt KHÔNG chặn thì lan 1 ô
  (trần cap chống khoá bàn). Render mứt đỏ/magenta. Khác chocolate (spread tím).

Weave vào vài màn score chưa dùng (≡ phù hợp mod, không trùng order/spread/bomb/
conveyor/portal/dispenser). Mục tiêu `clearObstacle` tái dùng.

## Việc
- Enum + builder weave màn. `_damageObstacles`/`_swapLocked`/`_matchColorAt` xử lý.
- `_maybeGrowJam` (lan). ObstacleLayer `_drawLicorice`/`_drawJam`.
- Guide thêm 2 obstacle. i18n en+vi.

## Test
- licorice cần 2 hit; jam lan ≤ cap; winnability (luôn còn cặp ô tự do kề nhau).
