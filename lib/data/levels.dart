import '../logic/gem_data.dart';

/// Loại mục tiêu của màn chơi.
enum ObjectiveType { score, collect, clearJelly }

/// Cách rải jelly trên bàn.
enum JellyPattern { none, all, checker, center }

class LevelConfig {
  final int index;
  final int rows;
  final int cols;
  final int colorCount;
  final int moves;
  final ObjectiveType objective;
  final int targetScore;
  final int collectTarget;
  final GemColor? collectColor;
  final JellyPattern jelly;

  const LevelConfig({
    required this.index,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.moves,
    this.objective = ObjectiveType.score,
    this.targetScore = 0,
    this.collectTarget = 0,
    this.collectColor,
    this.jelly = JellyPattern.none,
  });
}

/// Tổng số màn.
const int kLevelCount = 100;

/// 100 màn sinh tự động, độ khó tăng dần, xoay vòng 3 loại mục tiêu.
final List<LevelConfig> kLevels = List.generate(kLevelCount, (i) {
  final index = i + 1;
  // board 8x8 chuẩn
  const rows = 8, cols = 8;
  // màu: dễ ở đầu
  final colorCount = index <= 3
      ? 4
      : index <= 12
          ? 5
          : 6;
  // lượt: ít dần khi khó hơn
  final moves = (26 - index ~/ 8).clamp(15, 26);

  // màn 1 luôn là score (intro); sau đó xoay vòng score/collect/jelly
  final objective = index == 1
      ? ObjectiveType.score
      : ObjectiveType.values[(index - 1) % 3];

  switch (objective) {
    case ObjectiveType.score:
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves,
        objective: ObjectiveType.score,
        targetScore: 1000 + index * 220,
      );
    case ObjectiveType.collect:
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves,
        objective: ObjectiveType.collect,
        collectTarget: 14 + index ~/ 2,
        collectColor: GemColor.values[index % GemColor.values.length],
      );
    case ObjectiveType.clearJelly:
      final pattern = index < 30
          ? JellyPattern.center
          : index < 60
              ? JellyPattern.checker
              : JellyPattern.all;
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 4, // jelly cần thêm lượt
        objective: ObjectiveType.clearJelly,
        jelly: pattern,
      );
  }
});
