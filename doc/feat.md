# Pop Star Blast — feature tracker

Fork từ Neon Jewels sang cơ chế PopStar! (tap nhóm ô cùng màu liền kề để nổ,
không swap/cascade). Kế hoạch gốc: `/Users/loitran/.claude/plans/giggly-sprouting-piglet.md`.

## ✅ Implemented

- Đổi định danh project: package `pop_star_blast`, Android `com.galaxyjoy.pop_star_blast`,
  iOS `com.galaxyjoy.popStarBlast*`.
- Logic thuần Dart: `pop_detector.dart` (flood-fill nhóm cùng màu, `hasAnyMovableGroup`),
  `pop_collapse.dart` (gravity + dồn cột trái, không refill).
- `data/levels.dart`: 200 level tăng dần độ khó (rows/cols/colorCount/targetScore theo world).
- Flame game `PopStarGame` + `BlockComponent`: tap → pop → gravity → cascade check.
- `GameController` (điểm/sao/coin, không side-mode) + `GameScreenController`
  (vòng đời màn chơi, overlay, booster arm).
- Booster kinh tế cơ bản: bomb (60 xu, nổ 3x3), shuffle (40 xu), undo (30 xu).
- 6 màn hình: Home, Level Select (grid phẳng 200 level), Game, Shop, Guide, Settings
  (ngôn ngữ + âm thanh + reset progress).
- Test tối thiểu: unit (`pop_detector`, `pop_collapse`, `levels`), widget smoke
  + win-flow test, 1 integration lifecycle test.
- **Cân bằng độ khó**: `targetScore` neo vào diện tích bàn (`cells*6*ramp`) — công
  thức leo-tuyến-tính cũ khiến ~146/200 màn bất khả thi; nay greedy-bot qua 0/200.
- **UI neon glow chuẩn release**: `NeonTheme.glow` 3 lớp bloom; block = neon jewel
  (gradient + gloss + rim + bloom); Home 3 chip tròn neon; Game HUD có scrim + board
  canh giữa không đè HUD; verify tay full-flow trên Pixel 7 Pro.
- **Không quảng cáo**: app không tích hợp ad SDK nào; đã gỡ quyền thừa `AD_ID`.

## 💭 Ideas (chưa làm, ngoài scope MVP)

- Daily reward / login streak.
- Thêm booster mới (color bomb, rainbow color).
- Leaderboard / social.
- Cosmetic skins cho block.
