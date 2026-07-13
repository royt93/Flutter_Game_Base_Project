import 'dart:math';

/// F13: cấu hình cố định bàn Daily Challenge (không theo world như campaign —
/// 1 bàn chuẩn mỗi ngày để so điểm công bằng).
const int dailyChallengeRows = 9;
const int dailyChallengeCols = 8;
const int dailyChallengeColorCount = 5;

/// Sinh bàn Daily Challenge từ [seed] (dùng epoch-day làm seed, `Random(seed)`
/// có seed — không phải `Random()` mặc định) — cùng seed luôn ra cùng bàn.
List<List<int>> generateDailyChallengeGrid(int seed) {
  final rng = Random(seed);
  return List.generate(
    dailyChallengeRows,
    (_) => List.generate(
      dailyChallengeCols,
      (_) => rng.nextInt(dailyChallengeColorCount),
    ),
  );
}
