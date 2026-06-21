---
id: w20-3-meta-social-offline
title: Meta tiến trình & Social offline nâng cao
wave: 20
phase: 3
status: done
owner: claude
priority: medium
---

# Phase 3 — Meta & Social offline

## Bối cảnh
Game là OFFLINE thuần — không backend, không leaderboard real-time. Wave 20.3 thêm
tính năng social/meta cảm giác "có người khác" mà KHÔNG cần server.

## Tính năng đề xuất (chọn 2-3 để làm)

### A. Ghost Replay — Thử thách bóng ma (ưu tiên cao)
Lưu chuỗi nước đi tốt nhất của người chơi (best run một màn) → chơi lại màn đó hiển
thị "bóng ma" nước đi cũ.
- Lưu: `StorageKeys.ghostMoves(levelIndex)` → JSON compact (list of (r1,c1,r2,c2,t_ms))
  capped 200 moves
- Replay: GameController `ghostMode` flag → mỗi lượt hiển thị hint bóng ma (overlay mờ)
  tại vị trí ghost nước đi đó (thời gian tương đối)
- UX: nút "XEM BÓNG MA" trên Level Select (chỉ khi đã có ghost) → vào game với HUD
  "vs BÓNG MA: xxx điểm"
- Scope: chỉ màn campaign (không side mode)

### B. Progression Tree — Cây mở khoá (ưu tiên trung bình)
Dùng điểm meta (tổng sao + kỷ lục side mode) mở khoá hiệu ứng visual/cơ chế:
- Node A: 50 sao → unlock "Particle Burst x2" (double particle khi nổ)
- Node B: 100 sao → unlock "Hyper Combo" (combo text lớn hơn)
- Node C: 10 Gold Milestone (bất kỳ mode) → unlock "Prestige Skin" (skin đặc biệt)
- Màn `ProgressionTreeScreen` (dạng tech-tree 3 nhánh)
- Không p2w: chỉ visual/cosmetic, KHÔNG tăng lượt/điểm

### C. Challenge Card — Thử thách tuần (ưu tiên thấp)
Mỗi tuần 3 thử thách cụ thể (tất định theo tuần seed):
- VD: "Đạt combo x8 trong 1 ván" / "Thắng màn 45 trong ≤20 lượt" / "Kiếm 500 xu trong ngày"
- Hoàn thành → thưởng xu + coin-sink (nguyên liệu craft)
- Tái dùng `TournamentController` epoch-week pattern

## Triển khai (nếu làm A + B)

### Ghost Replay (A)
- `lib/core/storage_service.dart`: thêm `setGhostMoves` / `getGhostMoves`
- `lib/presentation/controllers/game_controller_modes.dart`: record moves (`_moveLog`)
  khi chơi màn campaign, flush khi win với score > highScore
- Overlay ghost trong `game_screen.dart`: `GhostOverlay` (Obx theo `ghostStep`)

### Progression Tree (B)
- `lib/data/progression_tree.dart`: định nghĩa nodes (cost, reward, deps)
- `ProgressionTreeController` (GetX permanent, đọc `totalStars` + `goldMilestones`)
- `ProgressionTreeScreen`: visualize tree với glow node đã mở khoá
- Apply effects: `ActiveCosmetics` đọc unlocked nodes → particle multiplier, etc.

## Rủi ro
- Ghost moves lưu nhiều data → cần cap + clear khi reset
- Progression tree complex UX → giữ đơn giản (3 nhánh × 3-4 node)
- Challenge Card overlap với Daily/SeasonLeague → cần phân biệt rõ mục đích
