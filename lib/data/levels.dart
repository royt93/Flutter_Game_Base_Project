import '../logic/pop_collapse.dart' show GravityDirection;

/// F6b: loại mục tiêu thắng màn ngoài điểm. [score] giữ nguyên luật cũ
/// (thắng khi bàn hết/kẹt, sao tính theo targetScore) — mặc định mọi màn.
/// F9: [collect] thu đúng [LevelObjective.target] ô màu (không cần dọn hết
/// trên bàn như [clearColor]); [moveLimitBonus] không phải điều kiện thắng,
/// chỉ +1 sao bonus nếu xong màn trong ≤[LevelObjective.moveLimit] lượt;
/// [obstacleInMoves] giống [clearObstacle] (phá đúng [LevelObjective.target]
/// ô obstacle) + cùng bonus sao theo lượt. I1: [openGift] mở đúng
/// [LevelObjective.target] ô quà (gift rơi tới đáy tự mở, xem
/// `logic/gift_tile.dart`).
enum ObjectiveType {
  score,
  clearColor,
  clearObstacle,
  collect,
  moveLimitBonus,
  obstacleInMoves,
  openGift,
}

/// Mục tiêu 1 màn. `clearColor`/`collect` cần [color]; `collect`/
/// `obstacleInMoves`/`openGift` cần [target]; `moveLimitBonus`/
/// `obstacleInMoves` cần [moveLimit]. `clearObstacle`/`score` không dùng
/// field nào.
class LevelObjective {
  final ObjectiveType type;
  final int? color;
  final int? target;
  final int? moveLimit;

  const LevelObjective.score()
    : type = ObjectiveType.score,
      color = null,
      target = null,
      moveLimit = null;
  const LevelObjective.clearColor(this.color)
    : type = ObjectiveType.clearColor,
      target = null,
      moveLimit = null;
  const LevelObjective.clearObstacle()
    : type = ObjectiveType.clearObstacle,
      color = null,
      target = null,
      moveLimit = null;
  const LevelObjective.collect(this.color, this.target)
    : type = ObjectiveType.collect,
      moveLimit = null;
  const LevelObjective.moveLimitBonus(this.moveLimit)
    : type = ObjectiveType.moveLimitBonus,
      color = null,
      target = null;
  const LevelObjective.obstacleInMoves(this.target, this.moveLimit)
    : type = ObjectiveType.obstacleInMoves,
      color = null;
  const LevelObjective.openGift(this.target)
    : type = ObjectiveType.openGift,
      color = null,
      moveLimit = null;
}

/// Cấu hình 1 màn Pop Star Blast.
class PopLevel {
  final int id;
  final int rows;
  final int cols;
  final int colorCount;
  final int targetScore;
  final LevelObjective objective;

  /// F11: level cuối mỗi world (id % 20 == 0) — target nhân
  /// [bossTargetMultiplier], icon/banner riêng trên path map.
  final bool isBoss;

  /// I3: hướng gravity của màn — mặc định [GravityDirection.down] (luật gốc).
  final GravityDirection gravityDirection;

  const PopLevel({
    required this.id,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.targetScore,
    this.objective = const LevelObjective.score(),
    this.isBoss = false,
    this.gravityDirection = GravityDirection.down,
  });
}

/// F11: hệ số nhân targetScore của boss level so với target thường cùng world.
const double bossTargetMultiplier = 1.5;

/// Điểm khi nổ 1 nhóm [n] ô: công thức chuẩn PopStar — càng nhóm to càng lời.
int scoreForGroup(int n) => 5 * n * (n - 1);

/// Thưởng khi dọn sạch toàn bộ bàn.
const int clearBoardBonus = 1000;

const int kLevelCount = 220;

/// 220 màn tăng dần độ khó: cols và colorCount nới rộng theo world (mỗi 20
/// màn). Bàn hữu hạn, KHÔNG refill → điểm đạt được scale theo số ô, không theo
/// index màn. Vì vậy targetScore neo vào `cells * 6` (ngưỡng 1-sao chơi thường)
/// và chỉ nhích nhẹ theo world; công thức leo-tuyến-tính cũ khiến ~146/200 màn
/// bất khả thi (đã xác minh bằng greedy-bot sim, xem doc/feat.md).
///
/// F9/X6 (task #6 2026-07-16): objective luân phiên theo chu kỳ 9 màn, lặp
/// lại suốt các màn — 3 màn score, rồi lần lượt clearColor/clearObstacle/
/// collect/moveLimitBonus/obstacleInMoves/openGift (slot 3..8). Thêm
/// `openGift` (I1, trước đó có cơ chế đầy đủ ở `pop_star_game.dart` nhưng
/// chưa từng được gán cho màn campaign nào).
///
/// I24 (task #14): World 11 (level 201-220, world index 10) mở rộng bằng
/// cách tăng [kLevelCount] — rows/cols/colorBase đều dùng `.clamp` trên biểu
/// thức theo `world` nên đã bão hoà ở trần (11/12/7) từ World 10, World 11
/// tự động dùng đúng trần đó với `ramp` nhích thêm (không cần đổi công thức).
final List<PopLevel> kLevels = List.generate(kLevelCount, (i) {
  final id = i + 1;
  final world = i ~/ 20; // 0..10
  final rows = 8 + (world ~/ 2).clamp(0, 3); // 8..11
  final cols = 6 + world.clamp(0, 6); // 6..12
  // I21: dao động +-1 quanh baseline theo world để level liền kề không dùng
  // chung 1 colorCount suốt 20 màn (trần/sàn khó 4..7 giữ nguyên).
  final colorBase = 4 + (world ~/ 3).clamp(0, 3); // 4..7
  final colorCount = (colorBase + (i % 3) - 1).clamp(4, 7);
  final cells = rows * cols;
  final ramp = 1.0 + world * 0.03;
  final isBoss = id % 20 == 0;
  final baseTarget = (cells * 6 * ramp).round();
  final targetScore = isBoss
      ? (baseTarget * bossTargetMultiplier).round()
      : baseTarget;
  final moveLimit = (cells ~/ 3).clamp(6, 30);
  final obstacleCount = (3 + world ~/ 2).clamp(3, 8);
  final slot = i % 9;
  // I25 (task #15): boss (level cuối mỗi world) không theo chu kỳ 9-slot
  // chung — luân phiên riêng 4 "boss variant" theo world để mỗi world có
  // trận chốt khác nhau, tái dùng nguyên ObjectiveType đã có (không thêm
  // mechanic mới). targetScore/bossTargetMultiplier giữ nguyên, không đổi.
  final bossVariant = world % 4;
  final objective = isBoss
      ? switch (bossVariant) {
          1 => LevelObjective.clearColor(i % colorCount),
          2 => LevelObjective.obstacleInMoves(obstacleCount, moveLimit),
          3 => LevelObjective.openGift(
            ((cells / colorCount) / 3).clamp(2, 8).round(),
          ),
          _ => const LevelObjective.score(),
        }
      : switch (slot) {
          3 => LevelObjective.clearColor(i % colorCount),
          4 => const LevelObjective.clearObstacle(),
          5 => LevelObjective.collect(
            i % colorCount,
            ((cells / colorCount) / 2).clamp(2, 12).round(),
          ),
          6 => LevelObjective.moveLimitBonus(moveLimit),
          7 => LevelObjective.obstacleInMoves(obstacleCount, moveLimit),
          8 => LevelObjective.openGift(
            ((cells / colorCount) / 3).clamp(2, 8).round(),
          ),
          _ => const LevelObjective.score(),
        };
  return PopLevel(
    id: id,
    rows: rows,
    cols: cols,
    colorCount: colorCount,
    targetScore: targetScore,
    objective: objective,
    isBoss: isBoss,
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

/// F12 Endless: bàn thứ [boardIndex] (0-based, tăng mỗi khi dọn sạch bàn
/// trước). Ramp liên tục (không chia world như campaign) — rows/cols/colors
/// nới rộng dần rồi kẹp trần để bàn không phình vô hạn. id âm giống các
/// side-mode khác, không đụng storage theo id.
PopLevel endlessLevelForIndex(int boardIndex) {
  final rows = (7 + boardIndex ~/ 4).clamp(7, 14);
  final cols = (6 + boardIndex ~/ 3).clamp(6, 14);
  final colorCount = (4 + boardIndex ~/ 6).clamp(4, 8);
  return PopLevel(
    id: -3,
    rows: rows,
    cols: cols,
    colorCount: colorCount,
    targetScore: 0,
  );
}

/// F13: bàn cho Daily Challenge — rows/cols/colorCount phải khớp
/// `dailyChallengeRows/Cols/ColorCount` (lib/logic/daily_challenge.dart) vì
/// bàn thật được sinh riêng từ seed theo ngày, PopLevel này chỉ định kích
/// thước hiển thị.
const PopLevel kDailyChallengeLevel = PopLevel(
  id: -4,
  rows: 9,
  cols: 8,
  colorCount: 5,
  targetScore: 0,
);
