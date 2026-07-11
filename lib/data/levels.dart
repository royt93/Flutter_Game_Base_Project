/// Cấu hình 1 màn Pop Star Blast.
class PopLevel {
  final int id;
  final int rows;
  final int cols;
  final int colorCount;
  final int targetScore;

  const PopLevel({
    required this.id,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.targetScore,
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
