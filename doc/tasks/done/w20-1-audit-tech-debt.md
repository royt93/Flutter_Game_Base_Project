---
id: w20-1-audit-tech-debt
title: Audit chất lượng code + dọn nợ kỹ thuật (Wave 17-19)
wave: 20
phase: 1
status: done
owner: claude
priority: high
---

# Phase 1 — Audit & kỹ thuật (ưu tiên cao nhất)

## Mục tiêu
Kiểm tra toàn bộ code từ Wave 17 đến Wave 19 (mega-commit), phát hiện lỗi/nợ kỹ thuật,
đảm bảo chất lượng trước khi tiếp tục build thêm tính năng.

## Scope audit (4 tầng — song song)

### Tầng 1: Engine & Logic
- `neon_jewel_game.dart` + `settle.dart` + `board_mechanics.dart`
- Cơ chế Daily Mutator (`only4Colors`, `sideGravity`, `doubleCombo`, `lowMoves`, `allJelly`,
  `noSpecial`) — kiểm tra interaction với engine settle/refill/special gem
- Puzzle mode (`isPuzzle`) — guard no-refill hoạt động đúng mọi nhánh gravity
- Side mode isolation với W17 mechanics (TideLayer, fog, moving walls)

### Tầng 2: Controllers
- `SeasonLeagueController` (gộp Season + Tournament) — chống exploit, reset, anti-double-claim
- `SideModeRecordController` — metric đúng theo mode (bestStage/bestScore/winCount),
  milestone dedup, reset đầy đủ
- `PuzzleController` — mở khoá tuần tự, verifiable solvability
- GameController modes: tương tác mutator × DDA/pity × bomb × conveyor × portal

### Tầng 3: UI & Screens
- `SeasonLeagueScreen` — countdown timezone, claim UX
- `PuzzleSelectScreen` — unlock flow
- `ShopScreen` — free skin unlock (W18.2 free unlock mechanism)
- `HomeScreen` — layout sau khi gộp Season/Tournament, lưới mode 2×5 still no-scroll

### Tầng 4: Test coverage
- Liệt kê test nào CÒN THIẾU cho W17.3/W17.4/W18.x/W19.x
- Kiểm tra integration test `app_test.dart` còn pass không sau mega-commit
- playtest.dart: `dart run tool/playtest.dart` — kết quả đường cong vẫn 0 màn quá khó

## Output
- Danh sách phát hiện (HIGH/MED/LOW) kèm `file:line`
- Fix ít nhất tất cả HIGH
- Kết quả: số test pass, 0 analyzer issue

## Ghi chú kỹ thuật
- Theo pattern audit Wave 11/12/16: 4 agent song song, mỗi phát hiện verify `file:line`
- Không chỉ đọc code mà phải probe/grep confirm
- Sau audit: chạy `flutter test` + `flutter analyze` để verify
