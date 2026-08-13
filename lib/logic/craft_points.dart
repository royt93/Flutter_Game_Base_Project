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

/// F19: mỗi ván thắng-không-full-clear cho **đúng một** phần thưởng từ số cell
/// còn sót — booster nếu đủ ngưỡng, ngược lại gom vào số dư craft point.
///
/// Tách thành hàm thuần thay vì để `if/else` nằm trong `checkEnd`: nhánh đó
/// cần `activeGame` thật nên chỉ test được bằng harness engine, mà quy tắc
/// "không trả hai lần" thì đáng khoá bằng test rẻ.
enum CraftOutcome { none, booster, bankPoints }

CraftOutcome craftOutcomeFor(int points, int threshold) {
  if (points >= threshold) return CraftOutcome.booster;
  if (points > 0) return CraftOutcome.bankPoints;
  return CraftOutcome.none;
}
