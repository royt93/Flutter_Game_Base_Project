/// F6b: loại mục tiêu thắng màn ngoài điểm. [score] giữ nguyên luật cũ
/// (thắng khi bàn hết/kẹt, sao tính theo targetScore) — mặc định mọi màn.
enum ObjectiveType { score, clearColor, clearObstacle }

/// Mục tiêu 1 màn. `clearColor` cần [color]; `clearObstacle`/`score` không
/// dùng field này.
class LevelObjective {
  final ObjectiveType type;
  final int? color;

  const LevelObjective.score() : type = ObjectiveType.score, color = null;
  const LevelObjective.clearColor(this.color) : type = ObjectiveType.clearColor;
  const LevelObjective.clearObstacle()
    : type = ObjectiveType.clearObstacle,
      color = null;
}

/// Cấu hình 1 màn Pop Star Blast.
class PopLevel {
  final int id;
  final int rows;
  final int cols;
  final int colorCount;
  final int targetScore;
  final LevelObjective objective;

  const PopLevel({
    required this.id,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.targetScore,
    this.objective = const LevelObjective.score(),
  });
}

/// Điểm khi nổ 1 nhóm [n] ô: công thức chuẩn PopStar — càng nhóm to càng lời.
int scoreForGroup(int n) => 5 * n * (n - 1);

/// Thưởng khi dọn sạch toàn bộ bàn.
const int clearBoardBonus = 1000;

const int kLevelCount = 200;

/// 200 màn tăng dần độ khó: cols và colorCount nới rộng theo world (mỗi 20
/// màn). Bàn hữu hạn, KHÔNG refill → điểm đạt được scale theo số ô, không theo
/// index màn. Vì vậy targetScore neo vào `cells * 6` (ngưỡng 1-sao chơi thường)
/// và chỉ nhích nhẹ theo world; công thức leo-tuyến-tính cũ khiến ~146/200 màn
/// bất khả thi (đã xác minh bằng greedy-bot sim, xem doc/feat.md).
final List<PopLevel> kLevels = List.generate(kLevelCount, (i) {
  final id = i + 1;
  final world = i ~/ 20; // 0..9
  final rows = 8 + (world ~/ 2).clamp(0, 3); // 8..11
  final cols = 6 + world.clamp(0, 6); // 6..12
  final colorCount = 4 + (world ~/ 3).clamp(0, 3); // 4..7
  final cells = rows * cols;
  final ramp = 1.0 + world * 0.03;
  final targetScore = (cells * 6 * ramp).round();
  return PopLevel(
    id: id,
    rows: rows,
    cols: cols,
    colorCount: colorCount,
    targetScore: targetScore,
  );
});

/// Bàn cho F8 side-mode (Time-attack / Zen). id âm — không trùng id campaign
/// 1..200 nên không đụng storage key theo id (highScore/star).
const PopLevel kTimeAttackLevel = PopLevel(
  id: -1,
  rows: 9,
  cols: 8,
  colorCount: 5,
  targetScore: 0,
);
const PopLevel kZenLevel = PopLevel(
  id: -2,
  rows: 9,
  cols: 8,
  colorCount: 5,
  targetScore: 0,
);
