---
id: w19-1-challenge-meta-progression
title: Meta tiến trình riêng cho từng chế độ Thử thách
wave: 19
phase: 1
status: todo
owner: claude
---

# Phase 1 — Meta tiến trình (cá nhân) cho từng chế độ phụ

## Vấn đề hiện tại
Các chế độ phụ (Endless, Boss, Rhythm, Gravity, Soda, ColorRush, Survival, Labyrinth,
Daily) **không có lý do để chơi lại** ngoài "thấy vui". Không có:
- Kỷ lục cá nhân có thể phá vỡ.
- Cảm giác tiến triển theo thời gian.
- Phần thưởng gắn với độ thành thục từng mode.

Hệ thống mốc hiện tại (Thành tựu, Album) chỉ đo lường Campaign, không đo side mode.

## Thiết kế — "Mode Record" mỗi chế độ phụ

### Cấu trúc dữ liệu
Mỗi chế độ phụ lưu:
- `bestScore` / `bestStage` / `bestTime` (tuỳ mode).
- `playCount` — số lần chơi.
- `streak` — ngày chơi liên tiếp (riêng Daily đã có).

### Milestone mở khoá theo từng mode
Mỗi mode có 3 mốc cứng (Bronze / Silver / Gold):
| Mode | Bronze | Silver | Gold |
|---|---|---|---|
| Endless | Stage 5 | Stage 15 | Stage 30 |
| Boss | Thắng Hồi 1 | Thắng Hồi 3 | Thắng Hồi 5 |
| Rhythm | Groove 5 | Best streak 15 | 3-sao ×3 ngày |
| Gravity | Lượt 20 | Lượt 50 | Lượt 100 |
| Soda | 3 chai | 8 chai | 15 chai |
| ColorRush | Score 2k | Score 5k | Score 10k |
| Survival | Tide push ×5 | Survive 30 lượt | Survive 60 lượt |
| Labyrinth | Hoàn 1 bộ tường | Hoàn 5 bộ | Phá 50 gem trong sương |

Phần thưởng: **badge riêng + nhỏ xu** (không phải cosmetic chính — giữ vai đó cho Album).
Badge hiển thị trên card side-mode ở Home (Bronze/Silver/Gold icon nhỏ).

### "New Best!" notification
Khi phá kỷ lục → flash "NEW BEST +Nđ" bay lên (tương tự COMBO text).

## Triển khai
- `lib/data/side_mode_records.dart`: model `SideModeRecord` + const mốc.
- `StorageService`: thêm key `rec_endless_*`, `rec_boss_*`, … (prefix rõ ràng).
- `GameController._onGameEnd`: nhánh `isSideMode` — cập nhật record + kiểm milestone.
- `home_screen.dart`: badge Bronze/Silver/Gold trên từng card side-mode.
- i18n: `rec_bronze/silver/gold`, `rec_new_best` (en/vi + 20 fallback).

## Test
- Record cập nhật đúng sau mỗi ván; không ghi khi thua (tuỳ mode).
- Milestone nhận 1 lần (anti-exploit giống achievement).
- `resetProgress` xoá record + milestone.
- Badge hiện đúng trên Home.

## Lưu ý
- KHÔNG đụng `win-streak` / `level-unlock` (chỉ đo side mode).
- Record KHÔNG share kinh tế với Campaign (badge chỉ là trang trí, xu nhỏ).
- Liên quan: [[side-mode-isolation]], [[balance-economy-principles]], [[reset-permanent-controllers]].
