/// I32 Craft Booster: đổi cell còn sót lại cuối màn thắng (không full-clear,
/// full-clear đã có `clearBoardBonus` riêng — xem `lib/data/levels.dart`)
/// thành "craft point" — mỗi [cellsPerCraftPoint] cell = 1 point, làm tròn
/// xuống. Chỉ tính cell màu thường (`v >= 0`); obstacle/gift/boss/countdown-
/// lock/wildcard đều mã hoá bằng giá trị âm nên tự loại trừ, không cần import
/// riêng từng module logic đặc biệt để check.
const cellsPerCraftPoint = 4;

int craftPointsForRemainingCells(List<List<int?>> grid) {
  final remaining = grid
      .expand((row) => row)
      .where((v) => v != null && v >= 0)
      .length;
  return remaining ~/ cellsPerCraftPoint;
}
