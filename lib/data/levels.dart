/// Định nghĩa level cho MVP (mode Score Target).
class LevelConfig {
  final int index;
  final int rows;
  final int cols;
  final int colorCount; // số màu gem dùng (3..6) — ít màu thì dễ hơn
  final int moves; // số lượt cho phép
  final int targetScore; // điểm cần đạt để thắng

  const LevelConfig({
    required this.index,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.moves,
    required this.targetScore,
  });
}

/// 5 level demo, độ khó tăng dần.
const List<LevelConfig> kLevels = [
  LevelConfig(index: 1, rows: 7, cols: 7, colorCount: 4, moves: 25, targetScore: 1500),
  LevelConfig(index: 2, rows: 7, cols: 7, colorCount: 5, moves: 22, targetScore: 2500),
  LevelConfig(index: 3, rows: 8, cols: 8, colorCount: 5, moves: 20, targetScore: 4000),
  LevelConfig(index: 4, rows: 8, cols: 8, colorCount: 6, moves: 20, targetScore: 6000),
  LevelConfig(index: 5, rows: 8, cols: 8, colorCount: 6, moves: 18, targetScore: 8000),
];
