/// W19.2 — Chế độ Cấu đố (Puzzle).
///
/// Khác biệt 🟢 A: bàn KHÔNG refill gem mới (hữu hạn) → phải khai thác bàn hiệu
/// quả để đạt mục tiêu điểm trước khi bàn cạn. Bàn seed CỐ ĐỊNH (cùng 1 cấu đố
/// mỗi lần) → học & tối ưu. Sao theo HIỆU SUẤT (lượt dư), KHÔNG tốn mạng.
///
/// Lưu ý thiết kế: mục tiêu là ĐIỂM (không phải "clear vùng exact-N") để bảo đảm
/// luôn giải được (verify bằng test greedy auto-solver — score goal hợp greedy).
/// Bàn hữu hạn vẫn tạo sức ép "tối đa hoá giá trị" — khác hẳn campaign (refill ∞).
library;

import 'levels.dart';

/// Một cấu đố: bàn seed cố định + mục tiêu điểm + ngân sách lượt.
class PuzzleDef {
  final int id; // 1-based, dùng cho unlock tuần tự + lưu sao
  final int seed; // seed bàn (cùng seed → cùng bàn)
  final int target; // điểm cần đạt
  final int maxMoves; // ngân sách lượt (hết → thua)
  final int colorCount; // số màu (ít hơn = dễ ghép hơn)

  const PuzzleDef({
    required this.id,
    required this.seed,
    required this.target,
    required this.maxMoves,
    required this.colorCount,
  });
}

/// Index ảo cho màn Puzzle (không thuộc 1..150).
const int kPuzzleLevelIndex = -7;

/// Bộ 8 cấu đố, khó dần (target tăng / lượt giảm / màu tăng). Tham số được
/// hiệu chỉnh để greedy auto-solver luôn đạt target trong ngân sách (xem test).
// Seed/target/maxMoves được CHỌN qua diagnostic quét (test in trần điểm bàn) +
// verify greedy ×1 (cận dưới) đạt target trong ngân sách → đảm bảo giải được.
// Game thật điểm CAO hơn (combo/special) → dư biên an toàn.
const List<PuzzleDef> kPuzzles = [
  PuzzleDef(id: 1, seed: 1026, target: 260, maxMoves: 24, colorCount: 4),
  PuzzleDef(id: 2, seed: 1028, target: 300, maxMoves: 22, colorCount: 4),
  PuzzleDef(id: 3, seed: 1007, target: 340, maxMoves: 22, colorCount: 4),
  PuzzleDef(id: 4, seed: 1002, target: 380, maxMoves: 20, colorCount: 4),
  PuzzleDef(id: 5, seed: 1004, target: 410, maxMoves: 20, colorCount: 4),
  PuzzleDef(id: 6, seed: 1036, target: 440, maxMoves: 18, colorCount: 5),
  PuzzleDef(id: 7, seed: 1031, target: 455, maxMoves: 18, colorCount: 5),
  PuzzleDef(id: 8, seed: 1024, target: 465, maxMoves: 18, colorCount: 5),
];

/// Số sao (1-3) theo HIỆU SUẤT: còn càng nhiều lượt càng nhiều sao.
int puzzleStarsFor(int movesLeft, int maxMoves) {
  if (maxMoves <= 0) return 1;
  final frac = movesLeft / maxMoves;
  if (frac >= 0.40) return 3;
  if (frac >= 0.15) return 2;
  return 1;
}

/// Cấu đố theo [id] (1-based); null nếu ngoài phạm vi.
PuzzleDef? puzzleById(int id) {
  if (id < 1 || id > kPuzzles.length) return null;
  return kPuzzles[id - 1];
}

/// Dựng [LevelConfig] cho 1 cấu đố: bàn 8×8 score-target (engine đọc cờ isPuzzle
/// để tắt refill). Seed bàn truyền qua GameController.boardSeed.
LevelConfig buildPuzzleLevel(PuzzleDef def) => LevelConfig(
      index: kPuzzleLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: def.colorCount,
      moves: def.maxMoves,
      objective: ObjectiveType.score,
      targetScore: def.target,
    );
