import 'dart:math' as math;

import '../logic/gem_data.dart';
import '../logic/settle.dart';

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
  // Wave 14 — Soda/Ngập nước (chế độ phụ): clear gem làm mực nước dâng, đẩy các
  // "chai nổi" lên — đưa đủ chai chạm đỉnh để thắng. Thiết kế fill-based (không
  // đụng gravity): mực nước = số gem clear tích luỹ; chai nổi theo mực nước.
  soda,
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

/// Cách rải jelly trên bàn. Wave 16: thêm `corner` (DEAD-ZONE) — rải vào 4 GÓC
/// (mỗi góc 2×2) → mục tiêu ở góc cô lập, khó match (ít ô kề) → buộc dùng special.
enum JellyPattern { none, all, checker, center, corner }

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
    case JellyPattern.corner:
      // 4 góc, mỗi góc 2×2 (16 ô) → dead-zone (mục tiêu ở góc cô lập).
      return (r < 2 || r >= rows - 2) && (c < 2 || c >= cols - 2);
  }
}

/// Loại chướng ngại (obstacle) phủ lên gem.
/// - spread: "chocolate" tự lan sang ô kề mỗi lượt nếu KHÔNG bị chặn (clear kề).
/// - licorice (Wave 14): khoá 2 LỚP — cần clear ô kề 2 lần để gỡ (lock cứng).
/// - jam (Wave 14): mứt — như chocolate (lan + khoá) NHƯNG là MỤC TIÊU clearObstacle;
///   mục tiêu đếm số lớp BAN ĐẦU (lan thêm không tăng mục tiêu → luôn khả thi).
/// - cage (Wave 15): gem bị NHỐT — vẫn THAM GIA match (khác stone/licorice phủ kín)
///   nhưng KHÔNG tự swap được; phải ghép chính gem đó (xếp hàng xóm) để vỡ lồng.
///   2 lớp, vỡ 1 lớp mỗi lần gem nhốt nằm trong match → "giải cứu" khi hết lồng.
enum ObstacleType { none, ice, chain, stone, spread, licorice, jam, cage }

/// Số lớp lồng của 1 ô cage (cần bấy nhiêu lần ghép-chính-nó để giải cứu).
const int kCageLayers = 2;

/// Các màn clearObstacle chuyển sang CAGE (gem nhốt — Wave 15): mục tiêu "giải
/// cứu" = dọn hết lớp lồng. {42,78} + thế giới 6-8 ({114,138}).
const Set<int> kCageLevels = {42, 78, 114, 138};

// ---------------------------------------------------------------------------
// Wave 15 — WEAVE bố cục/dòng chảy vào màn SCORE thế giới 6-8 (101-150). Đọc theo
// chỉ số màn (giống kBombLevels). Map: index → bản đồ ký tự. Chọn các màn score
// (index ≡ 1 mod 6): 103/115/127/139/145.
// ---------------------------------------------------------------------------

/// Bố cục tường/lỗ (+ no-drop) cho vài màn showcase. Hình hở đỉnh/đáy → refill OK.
const Map<int, List<String>> kLayoutLevels = {
  // 103 — hình thoi (4 góc tường)
  103: ['##....##', '#......#', '........', '........', '........', '........',
        '#......#', '##....##'],
  // 127 — cột trụ (tường dọc, gem lách qua bằng trượt chéo)
  127: ['........', '.#....#.', '.#....#.', '........', '........', '.#....#.',
        '.#....#.', '........'],
  // 145 — đảo nổi no-drop ('o' = gem bất động giữa bàn)
  145: ['........', '........', '..o..o..', '........', '........', '..o..o..',
        '........', '........'],
  // Wave 16 — BOTTLENECK (nút thắt cổ chai): waist tường chia bàn thành các BĂNG.
  // Tác dụng chính: match KHÔNG vượt qua tường → chặn combo dọc liên mạch (khó hơn).
  // Refill KHÔNG kẹt: ô ngay dưới mỗi ô tường là isSource (tự spawn) → mỗi băng tự
  // lấp độc lập, không cần gem lách qua khe. Score 109/121/133. Winnable: test mount
  // dưới (w16_deadzone_test) check fill đầy + hasMove ở nhiều seed.
  109: ['........', '........', '........', '##.##.##', '........', '........',
        '........', '........'],
  121: ['........', '........', '##.##.##', '........', '........', '##.##.##',
        '........', '........'],
  133: ['........', '##.##.##', '........', '........', '........', '##.##.##',
        '........', '........'],
};

/// Wave 16 — màn clearJelly đặt mục tiêu ở 4 GÓC (DEAD-ZONE). Chọn màn clearJelly
/// thế giới 6-8 (≡3 mod 6): 111, 129.
const Set<int> kDeadZoneLevels = {111, 129};

/// Dòng chảy (Gravity Streams) cho vài màn showcase.
const Map<int, List<String>> kFlowLevels = {
  // 115 — band giữa chảy phải
  115: ['vvvvvvvv', 'vvvvvvvv', 'vvvvvvvv', '>>>>>>>v', 'vvvvvvvv', 'vvvvvvvv',
        'vvvvvvvv', 'vvvvvvvv'],
  // 139 — 2 band ngược chiều (mạch điện)
  139: ['vvvvvvvv', '>>>>>>>v', 'vvvvvvvv', 'vvvvvvvv', 'v<<<<<<<', 'vvvvvvvv',
        'vvvvvvvv', 'vvvvvvvv'],
};

/// Các màn clearObstacle (index ≡ 0 mod 6) chuyển obstacle sang LICORICE (Wave 14):
/// khoá 2 lớp, cần 2 lần clear-kề/ô. Chọn 2 màn (mid + late game).
const Set<int> kLicoriceLevels = {48, 84};

/// Các màn clearObstacle chuyển sang JAM (mứt lan, Wave 14): lan như chocolate
/// nhưng là mục tiêu phải dọn (đếm lớp ban đầu). Chọn 2 màn (mid + late).
const Set<int> kJamLevels = {54, 90};

/// Số lớp khởi đầu của 1 ô licorice (cần bấy nhiêu lần clear-kề để gỡ).
const int kLicoriceLayers = 2;

/// Trần số ô jam (mứt) trên bàn — chống lan phủ kín gây khoá bàn. Phải NHỎ hơn
/// tổng ô bàn để luôn còn vùng tự do chơi (winnability guard, có test).
const int kJamSpreadCap = 24;

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

  /// Soda: số "chai" cần đẩy nổi lên đỉnh (0 nếu không phải Soda).
  final int sodaTarget;

  /// Wave 15 — BỐ CỤC bàn (ô tường/lỗ/no-drop). null = bàn đặc chữ nhật như cũ
  /// (KHÔNG hồi quy 100 màn hiện tại). Dựng từ bản đồ ký tự qua [layoutFromMap].
  final List<List<CellKind>>? layout;

  /// Wave 15 Phase 2 — DÒNG CHẢY (Gravity Streams): hướng trọng lực mỗi ô. null =
  /// toàn bộ chảy XUỐNG như thường. Dựng từ bản đồ `v/^/</>` qua [flowFromMap].
  final List<List<FlowDir>>? flow;

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
    this.sodaTarget = 0,
    this.layout,
    this.flow,
  });
}

/// Dựng bố cục từ bản đồ ký tự (mỗi String = 1 hàng). `#`/`X` = tường, `o`/`O` =
/// no-drop, còn lại = ô chơi. Số hàng/cột phải khớp rows/cols của màn.
List<List<CellKind>> layoutFromMap(List<String> rowsText) => parseLayout(rowsText);

/// Dựng lưới dòng chảy từ bản đồ `v/^/</>` (mỗi String = 1 hàng). Mặc định down.
List<List<FlowDir>> flowFromMap(List<String> rowsText) => parseFlow(rowsText);

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

/// Tổng số màn. Wave 15: mở rộng 100 → 150 (thế giới 6-8, weave cơ chế mới).
const int kLevelCount = 150;

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

/// 8 thế giới chủ đề neon (150 màn). Thế giới 6-8 (Wave 15): 101-120 / 121-140 /
/// 141-150 (thế giới cuối ngắn hơn — đỉnh cao thử thách).
const List<WorldConfig> kWorlds = [
  WorldConfig(index: 1, name: 'Cyan Nebula', startLevel: 1, endLevel: 20),
  WorldConfig(index: 2, name: 'Magenta Pulse', startLevel: 21, endLevel: 40),
  WorldConfig(index: 3, name: 'Lime Circuit', startLevel: 41, endLevel: 60),
  WorldConfig(index: 4, name: 'Amber Comet', startLevel: 61, endLevel: 80),
  WorldConfig(index: 5, name: 'Violet Void', startLevel: 81, endLevel: 100),
  WorldConfig(index: 6, name: 'Prism Maze', startLevel: 101, endLevel: 120),
  WorldConfig(index: 7, name: 'Flux Stream', startLevel: 121, endLevel: 140),
  WorldConfig(index: 8, name: 'Neon Apex', startLevel: 141, endLevel: 150),
];

// ---------------------------------------------------------------------------
// Wave 12 — Đường cong độ khó CÂN BẰNG (audit). Trước đây target tuyến tính
// (1000+index*220) + moves co → màn cuối cần 500-1231đ/lượt = BẤT KHẢ THI. Nay
// gắn target với SỐ LƯỢT → độ khó = ít slack dần (kiểu Candy Crush), luôn khả thi.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Wave 16 — TIER ĐỘ KHÓ + nhịp RĂNG CƯA (infographic Match-3). Mỗi màn gắn nhãn
// Normal/Hard/Super-Hard (phân bố ~70/25/5). Super-Hard ở ĐỈNH mỗi thế giới; 2 màn
// đầu thế giới kế = RELIEF (nghỉ + nới) → đường cong răng cưa thay vì đơn điệu.
// ---------------------------------------------------------------------------

/// Nhãn độ khó của 1 màn (hiển thị badge + điều chỉnh slack).
enum LevelTier { normal, hard, superHard }

/// Tier của màn [index] (1-based). Super-Hard = màn cuối mỗi thế giới (đỉnh);
/// Hard = 5 màn ngay trước đỉnh; còn lại Normal. Tất định → test + badge dùng được.
LevelTier levelTier(int index) {
  final w = worldOfLevel(index);
  if (index == w.endLevel) return LevelTier.superHard;
  // RELIEF (2 màn đầu thế giới sau Super-Hard) luôn Normal — ưu tiên trước Hard.
  if (isReliefLevel(index)) return LevelTier.normal;
  // Hard band ~25% kích thước thế giới (Wave 16 fix: trước đây HẰNG 5 màn → thế
  // giới cuối ngắn (TG8=10 màn) bị 50% Hard). Scale theo size → giữ ~25% đều.
  final size = w.endLevel - w.startLevel + 1;
  final band = (size / 4).round().clamp(2, 5);
  if (index >= w.endLevel - band && index < w.endLevel) return LevelTier.hard;
  return LevelTier.normal;
}

/// Màn "nghỉ" (relief) ngay sau 1 Super-Hard: 2 màn đầu mỗi thế giới (trừ thế giới
/// 1 — không có Super-Hard phía trước). Được nới lượt + giảm target (sawtooth).
bool isReliefLevel(int index) {
  final w = worldOfLevel(index);
  return w.index > 1 && index >= w.startLevel && index <= w.startLevel + 1;
}

/// Hệ số ĐỘ KHÓ theo tier: Super-Hard gắt hơn (đỉnh), Hard nhỉnh, Relief dễ. Áp
/// vào target (score/collect/time) → tier = ít/nhiều slack. Giữ winnability
/// (playtest re-validate; Super-Hard được MIỄN guard "quá khó").
double _tierMul(int index) {
  if (isReliefLevel(index)) return 0.85;
  switch (levelTier(index)) {
    case LevelTier.superHard:
      return 1.12;
    case LevelTier.hard:
      return 1.06;
    case LevelTier.normal:
      return 1.0;
  }
}

// ---------------------------------------------------------------------------
// Wave 16 Phase 4 — NEAR-MISS (infographic: cắt lượt màn khó tạo "suýt thắng").
// ⚠️ Game OFFLINE chưa IAP → KHÔNG dùng để ép mua. Làm bản CÔNG BẰNG = difficulty
// knob: chỉ Super-Hard (5%, đỉnh) cắt [kNearMissCut] lượt → độ khó đỉnh. Cờ tắt
// được (đặt false để bỏ near-miss hoàn toàn). Phần "hại" (cắt để ép mua) HOÃN.
// ---------------------------------------------------------------------------
const bool kNearMissEnabled = true;
const int kNearMissCut = 1; // số lượt cắt ở màn Super-Hard

/// Số lượt bị CẮT (near-miss) ở màn [index]: [kNearMissCut] nếu Super-Hard & bật,
/// ngược lại 0. Pure → test được + dùng chung.
int nearMissCutFor(int index) =>
    (kNearMissEnabled && levelTier(index) == LevelTier.superHard)
        ? kNearMissCut
        : 0;

/// Refill có ÉP màu mục tiêu không (Phase 4 RNG control — CHIỀU GIÚP). Pure (test
/// được): chỉ khi thua nhiều ([pity] ≥ [pityThreshold]) + màn collect + có màu mục
/// tiêu + [roll] < [bias]. KHÔNG dùng chiều anti-player.
bool biasRefillToTarget(int pity, int pityThreshold, ObjectiveType obj,
        bool hasTarget, double roll, double bias) =>
    pity >= pityThreshold && obj == ObjectiveType.collect && hasTarget &&
    roll < bias;

/// Điều chỉnh LƯỢT theo tier (sawtooth). relief +3 (nghỉ); Hard -1; Super-Hard -1
/// (đỉnh) + near-miss (gated). ⚠️ LƯU Ý: bite này bị SÀN 17 nuốt từ ~L75 (base đã
/// chạm sàn) → late-game tier dựa vào: _tierMul (score/time/collect) + _tierObjBonus
/// (jelly/dropDown). Đây chỉ là đòn bẩy early-mid + bù cho clearObstacle (không có
/// lever khác). KHÔNG phải "đòn bẩy duy nhất" — xem _collectCapMul / _tierObjBonus.
int _tierMoveDelta(int index) {
  if (isReliefLevel(index)) return 3;
  switch (levelTier(index)) {
    case LevelTier.superHard:
      return -1 - nearMissCutFor(index);
    case LevelTier.hard:
      return -1;
    case LevelTier.normal:
      return 0;
  }
}

/// Hệ số TRẦN collect theo tier (Wave 16 fix HIGH-2/3): trước đây cap=moves cho mọi
/// tier → _tierMul bị nuốt (relief==normal==hard==super = 1.0 gem/lượt). Nay trần
/// scale theo tier → bite hiện cả khi đã chạm sàn lượt: relief 0.85 (dễ rõ), normal
/// 1.0, hard 1.08, super 1.15 (cần cascade — đỉnh). Vẫn ≤1.5 (ngưỡng winnable test).
double _collectCapMul(int index) {
  if (isReliefLevel(index)) return 0.85;
  switch (levelTier(index)) {
    case LevelTier.superHard:
      return 1.15;
    case LevelTier.hard:
      return 1.08;
    case LevelTier.normal:
      return 1.0;
  }
}

/// Bớt LƯỢT-THƯỞNG objective theo tier (jelly/dropDown). Bonus cộng SAU sàn 17 nên
/// đây là đòn bẩy tier HIỆU QUẢ late-game (khác move-bite bị sàn nuốt từ ~L75). Hard
/// -1, Super -2; relief/normal 0. KHÔNG áp clearObstacle (pin winnability test W14).
int _tierObjBonus(int index) {
  if (isReliefLevel(index)) return 0;
  switch (levelTier(index)) {
    case LevelTier.superHard:
      return -2;
    case LevelTier.hard:
      return -1;
    case LevelTier.normal:
      return 0;
  }
}

/// Điểm/lượt KỲ VỌNG theo độ khó (ramp 42 → 82). 1 match-3 = 30đ. Hiệu chỉnh
/// theo auto-playtest (Wave 13): bot KHÔNG special pass ~30%+ ⇒ người chơi (dùng
/// special/booster, ~1.5-2× điểm) pass ~60-70%.
double _scorePerMove(int index) => (42 + index * 0.40).clamp(42, 82).toDouble();

/// Target điểm = base_moves × điểm/lượt kỳ vọng × hệ số tier (làm tròn 10).
int _scoreTarget(int index, int baseMoves) =>
    (baseMoves * _scorePerMove(index) * _tierMul(index) / 10).round() * 10;

/// Điểm/giây kỳ vọng cho Time Attack (ramp 22 → 34). Hiệu chỉnh mạnh theo
/// playtest (target cũ khiến không kịp); time-attack nên NHANH/VUI, không phải tường.
double _timePerSec(int index) => (22 + index * 0.14).clamp(22, 34).toDouble();
int _timeTarget(int index, int timeLimit) =>
    (timeLimit * _timePerSec(index) * _tierMul(index) / 10).round() * 10;

/// Số gem màu mục tiêu cần thu (Collect): ramp nhẹ, CLAMP ~1.0 gem/lượt — chỉ
/// ~1/6 bàn là màu mục tiêu (hiệu chỉnh xuống theo playtest).
int _collectTarget(int index, int moves) {
  final ramp = ((8 + index ~/ 6) * _tierMul(index)).round();
  final cap = (moves * _collectCapMul(index)).round();
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
  // lượt: ít dần khi khó hơn (sàn 17 — playtest cho thấy sàn 15 làm màn cuối
  // bị bóp lượt quá gắt, vd L85 chỉ 16 lượt). Wave 16: + delta theo tier (relief
  // +3 nghỉ, Super-Hard -1 siết đỉnh → nhịp răng cưa). Fix: clamp SÀN 17 lại SAU
  // khi cộng delta → near-miss không kéo Super-Hard xuống <17 (L80/L100/.. vốn đã
  // chạm sàn → near-miss tự vô hiệu, chỉ cắt ở màn còn dư lượt). Trần để mở (relief
  // +3 được vượt 26, như hành vi cũ vốn cộng +3 NGOÀI clamp).
  final moves =
      ((26 - index ~/ 8).clamp(17, 26) + _tierMoveDelta(index)).clamp(17, 99);

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
      // Wave 15: weave bố cục/dòng chảy vào màn score thế giới 6-8.
      final layoutMap = kLayoutLevels[index];
      final flowMap = kFlowLevels[index];
      // bàn có lỗ/dòng chảy → cho thêm lượt (khó định hướng hơn).
      if (layoutMap != null || flowMap != null) bonusMoves += 4;
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
        layout: layoutMap != null ? layoutFromMap(layoutMap) : null,
        flow: flowMap != null ? flowFromMap(flowMap) : null,
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
      // Wave 16 DEAD-ZONE: vài màn jelly đặt ở 4 GÓC (pattern corner) → mục tiêu
      // ở góc cô lập, khó match → buộc dùng special/booster. Cùng số ô (16) như
      // center nhưng vị trí khó hơn (không xô lệch tổng lượng).
      final jelly = kDeadZoneLevels.contains(index)
          ? JellyPattern.corner
          : tierPattern();
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + 4 + _tierObjBonus(index), // jelly +lượt; tier bớt (bite)
        objective: ObjectiveType.clearJelly,
        jelly: jelly,
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
        moves: moves + 6 + _tierObjBonus(index), // drop +lượt; tier bớt (bite)
        objective: ObjectiveType.dropDown,
        dropTarget: (2 + index ~/ 18).clamp(2, 6),
      );
    case ObjectiveType.clearObstacle:
      // ice (đầu) → chain (giữa) → stone (cuối); Wave 14 weave licorice/jam;
      // Wave 15 weave cage (gem nhốt — matchable + khoá swap).
      final licorice = kLicoriceLevels.contains(index);
      final jam = kJamLevels.contains(index);
      final cage = kCageLevels.contains(index);
      final type = cage
          ? ObstacleType.cage
          : licorice
              ? ObstacleType.licorice
              : jam
                  ? ObstacleType.jam
                  : index < 30
                      ? ObstacleType.ice
                      : index < 60
                          ? ObstacleType.chain
                          : ObstacleType.stone;
      // QUAN TRỌNG: chain/stone/licorice/jam/cage KHOÁ swap → pattern dày
      // (checker/all) sẽ làm bí cứng bàn. Chỉ ice (không khoá) mới dùng pattern
      // dày; còn lại luôn dùng `center` (chừa viền tự do để chơi). Cage còn cần
      // THƯA (engine lọc (r+c) chẵn) để 2 ô nhốt không kề nhau (luôn ghép được).
      final pattern =
          type == ObstacleType.ice ? tierPattern() : JellyPattern.center;
      // licorice 2 lớp / jam lan / cage 2 lớp → cho thêm lượt để công bằng.
      final extra = licorice ? 8 : (jam ? 7 : (cage ? 8 : 5));
      return LevelConfig(
        index: index,
        rows: rows,
        cols: cols,
        colorCount: colorCount,
        moves: moves + extra,
        objective: ObjectiveType.clearObstacle,
        obstacle: type,
        obstaclePattern: pattern,
      );
    case ObjectiveType.order:
    case ObjectiveType.endless:
    case ObjectiveType.boss:
    case ObjectiveType.soda:
      // Không bao giờ rơi vào đây (order weave qua kOrderLevels ở case score;
      // endless/boss/soda là chế độ riêng) — fallback score để switch exhaustive.
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

// --- Soda / Ngập nước (chế độ riêng — mực nước dâng, đẩy chai nổi lên đỉnh) ---
const int kSodaLevelIndex = -6;
const int kSodaMoves = 28;

/// Số chai cần đẩy nổi lên đỉnh để thắng.
const int kSodaBottles = 3;

/// Số gem cần clear để đẩy 1 chai nổi lên đỉnh (mực nước dâng theo gem clear).
const int kSodaFillPerBottle = 20;

/// Cấu hình chế độ Soda: bàn 8×8, 6 màu, đưa [kSodaBottles] chai lên đỉnh trong
/// [kSodaMoves] lượt. Khác biệt nằm ở cờ `isSoda` (clear gem → mực nước dâng).
LevelConfig buildSodaLevel() => const LevelConfig(
      index: kSodaLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kSodaMoves,
      objective: ObjectiveType.soda,
      sodaTarget: kSodaBottles,
    );

// --- Sinh tồn (Survival — Wave 15): đếm ngược, combo +giây, sống lâu = điểm cao ---
const int kSurvivalLevelIndex = -7;

// --- Wave 17.1 — Sinh tồn: cơ chế "TRIỀU DÂNG" (thay vì reskin TimeAttack) ---
// Mực nước DÂNG từ đáy theo thời gian (tăng tốc dần); clear gem DƯỚI NƯỚC đẩy lùi
// triều; nước chạm ĐỈNH (floodTop ≤ 0) → THUA. Khác hẳn TimeAttack: áp lực KHÔNG
// GIAN (clear thấp để sống), engine ĐỌC isSurvival thật (cũ: không đọc dòng nào).
const double kTideBaseRate = 0.06; // hàng/giây lúc mới vào (chậm)
const double kTideAccel = 0.0018; // gia tốc dâng (hàng/giây mỗi giây sống)
const double kTidePushback = 0.13; // đẩy lùi (hàng) mỗi gem DƯỚI NƯỚC bị clear

/// Tốc độ triều dâng (hàng/giây) tại [elapsed] giây đã sống — tăng tuyến tính.
/// Pure → unit-test được + dùng chung engine.
double tideRiseRate(double elapsed) => kTideBaseRate + kTideAccel * elapsed;

/// Cấu hình Survival (Triều dâng): objective `score` để KHÔNG dính đồng hồ/+giây
/// của timeAttack — kết thúc do TRIỀU (engine set `tideOverflow`), không do hết giờ.
/// `moves`/`targetScore` đặt khổng lồ để không bao giờ hết lượt / "win" sớm.
LevelConfig buildSurvivalLevel() => const LevelConfig(
      index: kSurvivalLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: 1 << 24, // không giới hạn lượt (chạy theo triều)
      objective: ObjectiveType.score,
      targetScore: 1 << 28, // không bao giờ đạt → không "win"
    );

// --- Mê cung neon (Labyrinth — Wave 15): đưa tinh thể qua mê cung tường xuống đáy ---
const int kLabyrinthLevelIndex = -8;
const int kLabyrinthMoves = 30;

/// Số tinh thể cần đưa xuống đáy để thắng.
const int kLabyrinthTarget = 4;

/// Bản đồ MÊ CUNG kiểu "phễu" (inverted-V) — Wave 15. Tường (#) xếp ANTI-CHÉO
/// để luật trượt-chéo của engine LUÔN kích hoạt: tinh thể đậu trên tường có tường
/// KỀ cùng hàng → trượt chéo ra mép rồi rơi thẳng xuống đáy. ĐÃ chứng minh khả thi
/// bằng sim descent (mọi cột đặt được c1-c6 tới đáy) + test `labyrinth khả thi`.
/// LƯU Ý: KHÔNG dùng hàng-tường-kẹp-giữa-hàng-mở (tinh thể sẽ kẹt — bản cũ lỗi).
const List<String> kLabyrinthMap = [
  '#......#',
  '.#....#.',
  '..#..#..',
  '...##...',
  '........',
  '........',
  '........',
  '........',
];

/// Cấu hình Labyrinth: TÁI DÙNG objective dropDown (cơ chế tinh thể + thu ở đáy)
/// + layout mê cung. Khác biệt ở cờ `isLabyrinth` (checkEnd nhánh riêng + isolation).
LevelConfig buildLabyrinthLevel() => LevelConfig(
      index: kLabyrinthLevelIndex,
      rows: 8,
      cols: 8,
      colorCount: 6,
      moves: kLabyrinthMoves,
      objective: ObjectiveType.dropDown,
      dropTarget: kLabyrinthTarget,
      layout: layoutFromMap(kLabyrinthMap),
    );

// --- W17.2: Mê cung tường động + sương mù ---

/// Tường dịch chuyển sau mỗi N lượt thật (không tính booster).
const int kMazeShiftMoves = 5;

/// Số hàng từ ĐÁY không bị sương mù (hàng top bị che).
const int kFogRadius = 4;

/// Chuỗi bố cục mê cung tuần hoàn — mỗi kMazeShiftMoves lượt thì sang layout kế tiếp.
/// BẤT BIẾN AN TOÀN: mọi layout đều có đường descent cho tinh thể qua luật anti-diagonal
/// của settleBoardFlow (đã verify bằng sim descent trong test).
const List<List<String>> kLabyrinthLayouts = [
  // 0: Inverted-V sâu (rows 0–3) — bố cục gốc W15
  ['#......#', '.#....#.', '..#..#..', '...##...', '........', '........', '........', '........'],
  // 1: Inverted-V nông (rows 0–1) — thông thoáng, buộc combo theo chiều dọc
  ['#......#', '.#....#.', '........', '........', '........', '........', '........', '........'],
  // 2: Inverted-V ngược hướng (tường ở trong, hàng 0–1) — cản trung tâm, cạnh mở
  ['...##...', '..#..#..', '........', '........', '........', '........', '........', '........'],
  // 3: Chéo đơn trái (rows 0–3) — bất đối xứng, mở hẳn bên phải
  ['#.......', '.#......', '..#.....', '...#....', '........', '........', '........', '........'],
];

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
    case ObjectiveType.soda:
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
