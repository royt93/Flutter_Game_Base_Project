import 'dart:math' as math;

import '../logic/gem_data.dart';

/// Loại mục tiêu của màn chơi.
/// - score: đạt điểm trong số lượt
/// - collect: thu đủ gem 1 màu
/// - clearJelly: phá hết jelly
/// - timeAttack: đạt điểm trong giới hạn THỜI GIAN (không tính lượt)
/// - dropDown: đưa đủ "ingredient" xuống đáy bàn
/// - clearObstacle: dọn sạch obstacle (ice/chain/stone)
/// - order: mục tiêu HỖN HỢP — thu đủ NHIỀU màu cùng lúc (Wave 10)
/// - endless: chế độ vô tận (thử thách tăng dần) — KHÔNG có "win", thua khi
///   hết lượt; ghép special hoàn lượt; obstacle xuất hiện theo stage.
enum ObjectiveType {
  score,
  collect,
  clearJelly,
  timeAttack,
  dropDown,
  clearObstacle,
  order,
  endless,
  boss,
}

/// 1 mục tiêu con của chế độ Order (thu đủ [target] gem màu [color]).
class OrderGoal {
  final GemColor color;
  final int target;
  const OrderGoal(this.color, this.target);
}

/// 6 mục tiêu xoay vòng cho 100 màn thường (KHÔNG gồm [ObjectiveType.endless] —
/// endless là chế độ riêng, không gắn vào level nào).
const List<ObjectiveType> kRotatingObjectives = [
  ObjectiveType.score,
  ObjectiveType.collect,
  ObjectiveType.clearJelly,
  ObjectiveType.timeAttack,
  ObjectiveType.dropDown,
  ObjectiveType.clearObstacle,
];

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

/// Các màn (vốn là score) được CHUYỂN sang mục tiêu hỗn hợp Order (Wave 10):
/// thu đủ 3 màu gem cùng lúc. Chọn 3 màn rải đều các thế giới (không trùng
/// kSpreadLevels). Giữ NGUYÊN kRotatingObjectives → không xô lệch màn khác.
const Set<int> kOrderLevels = {37, 67, 97};

/// Các màn score có HAZARD "bom đếm ngược" (Wave 10): mục tiêu vẫn là điểm,
/// nhưng vài quả bom đếm lùi mỗi lượt — để 1 quả về 0 (chưa tháo) → THUA ngay.
/// Tháo bom = clear gem nằm trên ô bom. Chọn màn score không trùng order/spread.
const Set<int> kBombLevels = {31, 49, 79};

/// Số quả bom seed mỗi màn bomb + số lượt đếm ngược khởi đầu (rộng rãi cho công bằng).
const int kBombCount = 3;
const int kBombCountdown = 12;

// ---------------------------------------------------------------------------
// Wave 11 — 3 cơ chế WEAVE vào màn score (KHÔNG đổi objective, tra cứu theo
// chỉ số màn ở engine — giống kBombLevels). Chọn các màn score CHƯA dùng cho
// order/spread/bomb (score level = index ≡ 1 mod 6): 13/19/25/43/61/85.
// ---------------------------------------------------------------------------

/// Băng chuyền: các hàng [beltRows] dịch toàn bộ gem 1 cột/lượt theo [dir]
/// (cyclic, gem trôi khỏi mép xuất hiện lại mép kia).
class ConveyorSpec {
  final Set<int> beltRows;
  final int dir; // +1 = sang phải, -1 = sang trái
  const ConveyorSpec(this.beltRows, this.dir);
}

/// Các màn score có băng chuyền (Wave 11).
const Map<int, ConveyorSpec> kConveyorSpec = {
  25: ConveyorSpec({3, 4}, 1),
  61: ConveyorSpec({2, 5}, -1),
};

/// Cổng dịch chuyển: clear 1 đầu cổng → ECHO clear đầu kia (1 hop, không lặp).
class PortalSpec {
  final List<List<Cell>> pairs; // mỗi cặp [A, B]
  const PortalSpec(this.pairs);
}

/// Các màn score có cổng dịch chuyển (Wave 11).
const Map<int, PortalSpec> kPortalSpec = {
  43: PortalSpec([
    [Cell(1, 1), Cell(6, 6)],
  ]),
  85: PortalSpec([
    [Cell(0, 3), Cell(7, 4)],
    [Cell(2, 0), Cell(5, 7)],
  ]),
};

/// Ô phát special định kỳ: mỗi [period] lượt, mỗi ô trong [cells] biến gem tại
/// đó thành 1 gem special (striped/bomb) → điểm tựa chiến thuật.
class DispenserSpec {
  final List<Cell> cells; // ô nguồn (thường ở hàng trên)
  final int period;
  const DispenserSpec(this.cells, this.period);
}

/// Các màn score có ô phát special (Wave 11).
const Map<int, DispenserSpec> kDispenserSpec = {
  13: DispenserSpec([Cell(0, 2), Cell(0, 5)], 4),
  19: DispenserSpec([Cell(0, 1), Cell(0, 6)], 3),
};

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

  /// Order: danh sách mục tiêu con (thu đủ nhiều màu). Rỗng nếu không phải Order.
  final List<OrderGoal> orders;

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
    this.orders = const [],
  });
}

/// Tạo cấu hình màn Order (mục tiêu hỗn hợp): thu đủ 3 màu khác nhau, target
/// tăng nhẹ theo [index]. Chọn 3 màu tất định theo index (không phụ thuộc RNG
/// → test được). Cho thêm lượt vì mục tiêu nặng hơn 1 màu đơn.
LevelConfig _buildOrderLevel(int index, int rows, int cols, int colorCount,
    int baseMoves) {
  final n = GemColor.values.length;
  // Màu khởi đầu XOAY theo level (37/67/97 ≡1 mod 6 → nếu dùng index%n sẽ TRÙNG
  // bộ màu). Dùng base = (index~/7)%n cho 3 bộ màu KHÁC nhau giữa các màn order,
  // lấy 3 màu LIÊN TIẾP (luôn phân biệt trong 1 màn).
  final base = (index ~/ 7) % n;
  final c0 = GemColor.values[base];
  final c1 = GemColor.values[(base + 1) % n];
  final c2 = GemColor.values[(base + 2) % n];
  // Target mỗi màu nhẹ hơn + nhiều lượt hơn (mục tiêu 3 màu nặng → cân bằng).
  final per = 7 + index ~/ 16; // 37→9, 67→11, 97→13 (tổng ≤ 39)
  return LevelConfig(
    index: index,
    rows: rows,
    cols: cols,
    colorCount: colorCount,
    moves: baseMoves + 12,
    objective: ObjectiveType.order,
    orders: [OrderGoal(c0, per), OrderGoal(c1, per), OrderGoal(c2, per)],
  );
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

// ---------------------------------------------------------------------------
// Wave 12 — Đường cong độ khó CÂN BẰNG (audit). Trước đây target tuyến tính
// (1000+index*220) + moves co → màn cuối cần 500-1231đ/lượt = BẤT KHẢ THI. Nay
// gắn target với SỐ LƯỢT → độ khó = ít slack dần (kiểu Candy Crush), luôn khả thi.
// ---------------------------------------------------------------------------

/// Điểm/lượt KỲ VỌNG theo độ khó (ramp 45 → 105). 1 match-3 = 30đ → ~3 match-3
/// hoặc 1-2 cascade mỗi lượt là khả thi cho người chơi gắn bó.
double _scorePerMove(int index) => (45 + index * 0.55).clamp(45, 105).toDouble();

/// Target điểm = base_moves × điểm/lượt kỳ vọng (làm tròn 10). [baseMoves] KHÔNG
/// gồm bonus hazard → hazard cho thêm lượt = thêm slack (đúng ý đồ).
int _scoreTarget(int index, int baseMoves) =>
    (baseMoves * _scorePerMove(index) / 10).round() * 10;

/// Điểm/giây kỳ vọng cho Time Attack (ramp 35 → 60). Không giới hạn lượt nên
/// áp lực đến từ thời gian.
double _timePerSec(int index) => (35 + index * 0.25).clamp(35, 60).toDouble();
int _timeTarget(int index, int timeLimit) =>
    (timeLimit * _timePerSec(index) / 10).round() * 10;

/// Số gem màu mục tiêu cần thu (Collect): ramp nhẹ nhưng CLAMP theo lượt
/// (~1.2 gem/lượt) — chỉ ~1/6 bàn là màu mục tiêu nên không thể đòi quá cao.
int _collectTarget(int index, int moves) {
  final ramp = 8 + index ~/ 5;
  final cap = (moves * 1.2).floor();
  return ramp < cap ? ramp : cap;
}

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
      : kRotatingObjectives[(index - 1) % kRotatingObjectives.length];

  // pattern theo tier (dùng chung cho jelly & obstacle)
  JellyPattern tierPattern() => index < 30
      ? JellyPattern.center
      : index < 60
          ? JellyPattern.checker
          : JellyPattern.all;

  switch (objective) {
    case ObjectiveType.score:
      // Wave 10: vài màn score chuyển sang Order (mục tiêu hỗn hợp 3 màu).
      if (kOrderLevels.contains(index)) {
        return _buildOrderLevel(index, rows, cols, colorCount, moves);
      }
      final spread = kSpreadLevels.contains(index);
      final bomb = kBombLevels.contains(index);
      // Wave 11: hazard băng chuyền → +lượt; cổng (định tuyến clear, trung tính)
      // & dispenser (lợi thế) → KHÔNG thêm lượt.
      final conveyor = kConveyorSpec.containsKey(index);
      var bonusMoves = 0;
      if (spread) {
        bonusMoves = 6;
      } else if (bomb) {
        bonusMoves = 4;
      } else if (conveyor) {
        bonusMoves = 5;
      }
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + bonusMoves,
        objective: ObjectiveType.score,
        // Wave 12: target gắn base_moves (chưa gồm bonus hazard) → khả thi.
        targetScore: _scoreTarget(index, moves),
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
        collectTarget: _collectTarget(index, moves), // Wave 12: clamp theo lượt
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
      final timeLimit = (75 - index ~/ 4).clamp(45, 75); // càng cao càng gắt
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: 999, // không giới hạn lượt (chạy theo thời gian)
        objective: ObjectiveType.timeAttack,
        targetScore: _timeTarget(index, timeLimit), // Wave 12: gắn thời gian
        timeLimit: timeLimit,
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
    case ObjectiveType.order:
    case ObjectiveType.endless:
    case ObjectiveType.boss:
      // Không bao giờ rơi vào đây (order weave qua kOrderLevels ở case score;
      // endless/boss là chế độ riêng) — fallback score để switch exhaustive.
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves,
        objective: ObjectiveType.score,
        targetScore: 1000 + index * 220,
      );
  }
});

/// Index ảo cho màn Endless (không thuộc 1..100).
const int kEndlessLevelIndex = 0;

/// Số lượt khởi đầu của Endless.
const int kEndlessStartMoves = 20;

/// Mỗi mốc điểm này → tăng 1 stage (khó hơn, đổi màu accent).
const int kEndlessStageScore = 1500;

/// Tạo cấu hình màn Endless: bàn 8×8, 6 màu, lượt khởi đầu hữu hạn nhưng
/// được hoàn khi ghép lớn — thua khi hết lượt. Difficulty tăng theo stage
/// (xử lý động trong GameController, không cố định ở đây).
LevelConfig buildEndlessLevel() => const LevelConfig(
      index: kEndlessLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kEndlessStartMoves,
      objective: ObjectiveType.endless,
    );

// --- Boss neon (chế độ riêng — đánh trùm theo lượt) ---
const int kBossLevelIndex = -1;

/// Số lượt cho mỗi trận boss (đánh trùm trong giới hạn lượt).
const int kBossMoves = 30;

/// Máu boss cơ bản; nhân theo stage trong GameController.
const int kBossBaseHp = 1200;

/// Tạo cấu hình trận boss: bàn 8×8, 6 màu, đánh trùm trong [kBossMoves] lượt.
LevelConfig buildBossLevel() => const LevelConfig(
      index: kBossLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kBossMoves,
      objective: ObjectiveType.boss,
    );

// --- Color Rush (chế độ riêng — màu "nóng" đổi liên tục, đua điểm) ---
const int kColorRushLevelIndex = -4;
const int kColorRushMoves = 30;
const int kColorRushTarget = 3500;

/// Đổi màu "nóng" mỗi bao nhiêu lượt.
const int kColorRushChangeEvery = 4;

/// Điểm thưởng cho MỖI gem màu nóng được clear (cộng thẳng, không qua combo).
const int kColorRushBonusPerGem = 15;

/// Cấu hình Color Rush: tái dùng mục tiêu điểm (score) để dùng sẵn HUD/sao;
/// khác biệt nằm ở cờ `isColorRush` (clear màu nóng → điểm bội, đổi màu mỗi N lượt).
LevelConfig buildColorRushLevel() => const LevelConfig(
      index: kColorRushLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kColorRushMoves,
      objective: ObjectiveType.score,
      targetScore: kColorRushTarget,
    );

// --- Trọng lực động (chế độ riêng — lật trọng lực mỗi N lượt) ---
const int kGravityLevelIndex = -2;
const int kGravityMoves = 28;
const int kGravityTarget = 2600;

/// Cứ mỗi bao nhiêu lượt thì bàn tự lật trọng lực (đảo cột).
const int kGravityFlipEvery = 5;

/// Cấu hình chế độ Trọng lực động: dùng mục tiêu điểm (score) để tận dụng sẵn
/// HUD/sao; điểm khác biệt là engine tự lật bàn định kỳ (xem GameController).
LevelConfig buildGravityLevel() => const LevelConfig(
      index: kGravityLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kGravityMoves,
      objective: ObjectiveType.score,
      targetScore: kGravityTarget,
    );

// --- Rhythm mode (chế độ riêng — ghép gem theo nhịp nhạc) ---
const int kRhythmLevelIndex = -3;
const int kRhythmMoves = 30;
const int kRhythmTarget = 4000;

/// Nhịp của chế độ Rhythm (BPM). Engine tích luỹ thời gian → mốc beat.
const double kRhythmBpm = 100;

/// Cấu hình chế độ Nhịp điệu: tái dùng mục tiêu điểm (score) để dùng sẵn HUD/sao;
/// khác biệt nằm ở cờ `isRhythm` của GameController (đúng nhịp → groove + thưởng điểm).
LevelConfig buildRhythmLevel() => const LevelConfig(
      index: kRhythmLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kRhythmMoves,
      objective: ObjectiveType.score,
      targetScore: kRhythmTarget,
    );

// --- Versus / Co-op (2 người, chạy engine Flame như mode thường) ---
const int kVersusLevelIndex = -4;

/// Cấu hình 1 bàn Versus: 7×7 (gọn để 2 bàn trên 1 màn), 6 màu, mục tiêu điểm
/// (không có điều kiện thắng từ engine — đồng hồ ngoài quyết định). Lượt "vô hạn".
LevelConfig buildVersusLevel() => const LevelConfig(
      index: kVersusLevelIndex,
      rows: 7,
      cols: 7,
      colorCount: 6,
      moves: 999999,
      objective: ObjectiveType.score,
      targetScore: 0,
    );

// --- Thử thách hằng ngày (Wave 9 — puzzle theo NGÀY) ---
const int kDailyLevelIndex = -5;

/// Số lượt nền của thử thách ngày (cộng thêm chút ngẫu nhiên-tất-định theo ngày).
const int kDailyBaseMoves = 24;

/// Mục tiêu xoay vòng cho thử thách ngày. CỐ TÌNH bỏ [ObjectiveType.timeAttack]
/// (phụ thuộc đồng hồ, khó so công bằng) và các chế độ riêng (endless/boss).
const List<ObjectiveType> kDailyObjectives = [
  ObjectiveType.score,
  ObjectiveType.collect,
  ObjectiveType.clearJelly,
  ObjectiveType.dropDown,
  ObjectiveType.clearObstacle,
];

/// Cấu hình màn "Thử thách hằng ngày" sinh TẤT ĐỊNH từ [epochDay] → mọi người
/// chơi CÙNG bàn + CÙNG mục tiêu trong ngày (bàn seed bằng chính `epochDay`
/// truyền cho engine). Cùng `epochDay` ⇒ cùng config (test được, không cần Flame).
/// Bàn 8×8, 6 màu, độ khó nhỉnh hơn mid-game nhưng vẫn qua được.
LevelConfig buildDailyLevel(int epochDay) {
  final rnd = math.Random(epochDay);
  const rows = 8, cols = 8, colorCount = 6;
  final objective = kDailyObjectives[epochDay % kDailyObjectives.length];
  final moves = kDailyBaseMoves + rnd.nextInt(5); // 24..28

  switch (objective) {
    case ObjectiveType.collect:
      return LevelConfig(
        index: kDailyLevelIndex,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves,
        objective: ObjectiveType.collect,
        collectTarget: 20 + rnd.nextInt(12), // 20..31
        collectColor: GemColor.values[rnd.nextInt(GemColor.values.length)],
      );
    case ObjectiveType.clearJelly:
      return LevelConfig(
        index: kDailyLevelIndex,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 4,
        objective: ObjectiveType.clearJelly,
        jelly: rnd.nextBool() ? JellyPattern.checker : JellyPattern.center,
      );
    case ObjectiveType.dropDown:
      return LevelConfig(
        index: kDailyLevelIndex,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 6,
        objective: ObjectiveType.dropDown,
        dropTarget: 3 + rnd.nextInt(3), // 3..5
      );
    case ObjectiveType.clearObstacle:
      // CHỈ dùng ICE: chain/stone khoá swap → pattern dày dễ làm bí bàn (xem ghi
      // chú ở kLevels). Ice an toàn cho 1 màn chơi seed cứng.
      return LevelConfig(
        index: kDailyLevelIndex,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 5,
        objective: ObjectiveType.clearObstacle,
        obstacle: ObstacleType.ice,
        obstaclePattern:
            rnd.nextBool() ? JellyPattern.checker : JellyPattern.center,
      );
    case ObjectiveType.score:
    case ObjectiveType.timeAttack:
    case ObjectiveType.order:
    case ObjectiveType.endless:
    case ObjectiveType.boss:
      return LevelConfig(
        index: kDailyLevelIndex,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves,
        objective: ObjectiveType.score,
        targetScore: 3200 + rnd.nextInt(9) * 250, // 3200..5200
      );
  }
}

/// Key i18n tên thế giới (1-based). Dùng `.tr` để lấy bản dịch.
String worldNameKey(int worldIndex) => 'world_name_$worldIndex';

/// Thế giới chứa [level] (1-based). Trả về world cuối nếu vượt ngưỡng.
WorldConfig worldOfLevel(int level) {
  for (final w in kWorlds) {
    if (w.contains(level)) return w;
  }
  return kWorlds.last;
}
