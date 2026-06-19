---
id: w15-3-caged-gem
title: Gem nhốt (Cage) + ô no-drop + mục tiêu Giải cứu
wave: 15
phase: 3
status: done
owner: claude
---

# Phase 3 — Caged gem + no-drop cells + rescue objective

## Gem nhốt (Cage) — obstacle phủ gem loại mới
- `ObstacleType.cage`: gem CÓ MÀU, **vẫn tham gia match** (khác hẳn chain/stone vốn
  chặn cứng). Khi gem trong lồng lọt vào 1 match → vừa nổ vừa "mở lồng". Có thể
  nhiều lớp lồng (`kCageLayers`): mỗi lần gem nằm trong match gỡ 1 lớp, hết lớp
  thì nổ bình thường.
- Khi còn lồng: **không tự swap** (swap-lock), nhưng gem khác swap cạnh tạo match
  chứa nó vẫn tính.
- Render `_drawCage` (song sắt neon + lõi gem mờ).

## Mục tiêu Giải cứu
- `ObjectiveType.rescue`: giải cứu đủ N gem nhốt (mỗi gem mở lồng hoàn toàn = +1).
  HUD chip "🔓 x/N". Đi qua nhánh win thường (tính sao/streak/unlock nếu là màn thường).

## Ô no-drop (từ Phase 0)
- Wire `CellKind.noDrop`: gem ở đó match được nhưng KHÔNG bị flow/gravity kéo
  (giữ vị trí). Refill bỏ qua. Tạo "đảo nổi" / cấu trúc tĩnh giữa bàn.

## Test
- Cage: gem nhốt match được, mở lồng theo lớp; swap-lock đúng; objective rescue
  đếm đúng + win khi đủ. no-drop: gem không bị kéo, vẫn match/nổ được.
