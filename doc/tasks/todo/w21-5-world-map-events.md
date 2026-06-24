---
id: w21-5-world-map-events
title: World Map — Event chest + mini-boss node + nhân vật đi bộ
wave: 21
phase: 5
status: todo
owner: claude
---

# Phase 5 — World Map Events

## Vấn đề hiện tại

World Map (Wave 5.3/6): node màn uốn lượn, path neon, xung năng lượng, sao lấp lánh.
Nhưng map là **tĩnh** — không có gì khác nhau mỗi thế giới ngoài màu accent.

## Thiết kế mới (3 tính năng)

### A. Treasure Chest Node (Rương báu)

Mỗi thế giới có 1 rương báu tại màn giữa (e.g. màn 10 của TG, tức level 10/30/50/70...).
- Node rương nhỏ màu vàng neon, không phải "màn chơi".
- Tap → hiện `ChestRewardOverlay`: thưởng xu ngẫu nhiên (50-150) hoặc booster ×1.
- Chỉ nhận được **1 lần/thế giới** (persist key `chestClaimed_world_N`).
- Mở khoá sau khi hoàn thành ≥8/10 màn trong thế giới đó.
- Hiện badge "🎁" chưa nhận, "✓" sau khi nhận.

Data: `kChestLevels = {1: 10, 2: 30, 3: 50, ...}` (level trung điểm mỗi TG).

### B. Mini-Boss Node (Quái trùm nhỏ)

Mỗi 2 thế giới có 1 mini-boss node tại màn cuối thế giới (level 20/40/60...).
- Node có icon đầu lâu neon nhấp nháy.
- Bấm vào → vào **Boss Mode** với HP thấp hơn boss thường (50% maxHp).
- Thắng → nhận 3× xu thưởng boss thường + "World Badge" (cosmetic nhỏ — hình dạng neon).
- Nếu thua: có thể thử lại ngay (không trừ mạng nếu bật `isBoss`).
- State: `miniBossCleared_world_N` (persist, không reset).

### C. Nhân vật đi bộ dọc path (Cosmetic)

Avatar neon nhỏ (hình viên kim cương) "đi" theo path từ node trước → node hiện tại.
- Animation: `AnimatedPositioned` dựa trên `_pathPositions[currentLevel]`.
- Đơn giản: không cần sprite sheet, vẽ `CustomPainter` hình gem nhỏ glow neon.
- Tốc độ di chuyển: 0.5s khi World Map mở (chạy 1 lần khi mount).

## Triển khai

- `WorldMapScreen`: thêm `_buildChestNode()` + `_buildMiniBossNode()` (insert vào list
  widgets theo index trong `kChestLevels`/`kMiniBossLevels`).
- `GameController`: thêm `claimWorldChest(world)` + `isChestClaimed(world)` trong
  `game_controller_economy.dart`.
- `ChestRewardOverlay` widget (dùng `NeonDialog.overlay`).
- Avatar: `_GemAvatarPainter` (CustomPainter đơn giản, ~30 dòng).

## Test
- `claimWorldChest` không nhận 2 lần (anti-exploit).
- Mini-boss isolation: isBoss isolation không trừ mạng.
- Widget test: `WorldMapScreen` mount với chest + mini-boss node.

## Lưu ý
- Mini-boss tái dùng `startBoss()` đã có, chỉ đổi `maxHp` parameter.
- Chest reward dùng `addCoins` đã có (ghi guard-key trước).
- Liên quan: [[side-mode-isolation]], [[currency-persistence-convention]].
