import '../logic/gem_data.dart';

/// Loại mục tiêu của màn chơi.
/// - score: đạt điểm mục tiêu
/// - collect: thu thập đủ N gem của 1 màu
/// - clearJelly: phá hết lớp jelly
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

  /// Điểm cần đạt (chỉ dùng cho objective = score).
  final int targetScore;

  /// Số gem cần thu thập + màu (chỉ dùng cho objective = collect).
  final int collectTarget;
  final GemColor? collectColor;

  /// Kiểu rải jelly (chỉ dùng cho objective = clearJelly).
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

/// 5 level demo với 3 loại mục tiêu khác nhau.
const List<LevelConfig> kLevels = [
  LevelConfig(
    index: 1,
    rows: 8,
    cols: 8,
    colorCount: 4,
    moves: 25,
    objective: ObjectiveType.score,
    targetScore: 1500,
  ),
  LevelConfig(
    index: 2,
    rows: 8,
    cols: 8,
    colorCount: 5,
    moves: 22,
    objective: ObjectiveType.collect,
    collectTarget: 20,
    collectColor: GemColor.cyan,
  ),
  LevelConfig(
    index: 3,
    rows: 8,
    cols: 8,
    colorCount: 5,
    moves: 25,
    objective: ObjectiveType.clearJelly,
    jelly: JellyPattern.center,
  ),
  LevelConfig(
    index: 4,
    rows: 8,
    cols: 8,
    colorCount: 6,
    moves: 22,
    objective: ObjectiveType.collect,
    collectTarget: 28,
    collectColor: GemColor.magenta,
  ),
  LevelConfig(
    index: 5,
    rows: 8,
    cols: 8,
    colorCount: 6,
    moves: 30,
    objective: ObjectiveType.clearJelly,
    jelly: JellyPattern.checker,
  ),
];
