import 'dart:math';

/// F13: cấu hình cố định bàn Daily Challenge (không theo world như campaign —
/// 1 bàn chuẩn mỗi ngày để so điểm công bằng).
const int dailyChallengeRows = 9;
const int dailyChallengeCols = 8;
const int dailyChallengeColorCount = 5;

/// Sinh bàn Daily Challenge từ [seed] (dùng epoch-day làm seed, `Random(seed)`
/// có seed — không phải `Random()` mặc định) — cùng seed luôn ra cùng bàn.
/// [colorCount] tùy chọn (mặc định [dailyChallengeColorCount]) — I33 Gauntlet
/// tái dùng hàm này với modifier "chỉ 4 màu".
List<List<int>> generateDailyChallengeGrid(
  int seed, {
  int colorCount = dailyChallengeColorCount,
}) {
  final rng = Random(seed);
  return List.generate(
    dailyChallengeRows,
    (_) => List.generate(dailyChallengeCols, (_) => rng.nextInt(colorCount)),
  );
}
