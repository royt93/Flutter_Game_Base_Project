import '../logic/gem_data.dart';

/// Loại mục tiêu của màn chơi.
/// - score: đạt điểm trong số lượt
/// - collect: thu đủ gem 1 màu
/// - clearJelly: phá hết jelly
/// - timeAttack: đạt điểm trong giới hạn THỜI GIAN (không tính lượt)
/// - dropDown: đưa đủ "ingredient" xuống đáy bàn
/// - clearObstacle: dọn sạch obstacle (ice/chain/stone)
enum ObjectiveType {
  score,
  collect,
  clearJelly,
  timeAttack,
  dropDown,
  clearObstacle,
}

/// Cách rải jelly trên bàn.
enum JellyPattern { none, all, checker, center }

/// Ô (r,c) có nằm trong pattern không (dùng chung cho jelly & obstacle).
/// Tách thuần để test winnability không cần khởi tạo game Flame.
bool patternHas(JellyPattern p, int r, int c, int rows, int cols) {
  switch (p) {
    case JellyPattern.none:
      return false;
    case JellyPattern.all:
      return true;
    case JellyPattern.checker:
      return (r + c).isEven;
    case JellyPattern.center:
      final r0 = (rows - 4) ~/ 2, c0 = (cols - 4) ~/ 2;
      return r >= r0 && r < r0 + 4 && c >= c0 && c < c0 + 4;
  }
}

/// Loại chướng ngại (obstacle) phủ lên gem.
/// - spread: "chocolate" tự lan sang ô kề mỗi lượt nếu KHÔNG bị chặn (clear kề).
enum ObstacleType { none, ice, chain, stone, spread }

/// Các màn (score) có thêm hazard lan tỏa (chocolate) — không phải mục tiêu,
/// chỉ là chướng ngại động người chơi phải kìm hãm.
const Set<int> kSpreadLevels = {55, 73, 91};

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

  /// Time Attack: giới hạn thời gian (giây).
  final int timeLimit;

  /// Drop Down: số ingredient cần đưa xuống đáy.
  final int dropTarget;

  /// Obstacle: loại + cách rải (tái dùng JellyPattern).
  final ObstacleType obstacle;
  final JellyPattern obstaclePattern;

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
    this.timeLimit = 0,
    this.dropTarget = 0,
    this.obstacle = ObstacleType.none,
    this.obstaclePattern = JellyPattern.none,
  });
}

/// Tổng số màn.
const int kLevelCount = 100;

/// Một "thế giới" (khu vực) gom [kWorldSize] màn, có chủ đề neon riêng.
class WorldConfig {
  final int index; // 1-based
  final String name; // tên chủ đề (proper noun, không dịch)
  final int startLevel;
  final int endLevel;
  const WorldConfig({
    required this.index,
    required this.name,
    required this.startLevel,
    required this.endLevel,
  });

  bool contains(int level) => level >= startLevel && level <= endLevel;
}

/// Mỗi thế giới gồm 20 màn.
const int kWorldSize = 20;

/// 5 thế giới chủ đề neon (100 màn / 20).
const List<WorldConfig> kWorlds = [
  WorldConfig(index: 1, name: 'Cyan Nebula', startLevel: 1, endLevel: 20),
  WorldConfig(index: 2, name: 'Magenta Pulse', startLevel: 21, endLevel: 40),
  WorldConfig(index: 3, name: 'Lime Circuit', startLevel: 41, endLevel: 60),
  WorldConfig(index: 4, name: 'Amber Comet', startLevel: 61, endLevel: 80),
  WorldConfig(index: 5, name: 'Violet Void', startLevel: 81, endLevel: 100),
];

/// 100 màn sinh tự động, độ khó tăng dần, xoay vòng 6 loại mục tiêu.
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

  // màn 1 luôn là score (intro); sau đó xoay vòng 6 loại mục tiêu
  final objective = index == 1
      ? ObjectiveType.score
      : ObjectiveType.values[(index - 1) % ObjectiveType.values.length];

  // pattern theo tier (dùng chung cho jelly & obstacle)
  JellyPattern tierPattern() => index < 30
      ? JellyPattern.center
      : index < 60
          ? JellyPattern.checker
          : JellyPattern.all;

  switch (objective) {
    case ObjectiveType.score:
      final spread = kSpreadLevels.contains(index);
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: spread ? moves + 6 : moves, // hazard lan tỏa → thêm lượt
        objective: ObjectiveType.score,
        targetScore: 1000 + index * 220,
        obstacle: spread ? ObstacleType.spread : ObstacleType.none,
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
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 4, // jelly cần thêm lượt
        objective: ObjectiveType.clearJelly,
        jelly: tierPattern(),
      );
    case ObjectiveType.timeAttack:
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: 999, // không giới hạn lượt (chạy theo thời gian)
        objective: ObjectiveType.timeAttack,
        targetScore: 900 + index * 160,
        timeLimit: (75 - index ~/ 4).clamp(45, 75), // càng cao càng gắt
      );
    case ObjectiveType.dropDown:
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 6, // đưa item xuống cần thêm lượt
        objective: ObjectiveType.dropDown,
        dropTarget: (2 + index ~/ 18).clamp(2, 6),
      );
    case ObjectiveType.clearObstacle:
      // ice (đầu) → chain (giữa) → stone (cuối)
      final type = index < 30
          ? ObstacleType.ice
          : index < 60
              ? ObstacleType.chain
              : ObstacleType.stone;
      // QUAN TRỌNG: chain & stone KHOÁ swap → pattern dày (checker/all) sẽ làm
      // bí cứng bàn (mọi nước đi bị khoá). Chỉ ice (không khoá) mới dùng được
      // pattern dày. chain/stone luôn dùng `center` (chừa viền tự do để chơi).
      final pattern =
          type == ObstacleType.ice ? tierPattern() : JellyPattern.center;
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 5,
        objective: ObjectiveType.clearObstacle,
        obstacle: type,
        obstaclePattern: pattern,
      );
  }
});
