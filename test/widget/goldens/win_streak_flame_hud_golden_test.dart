import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/win_streak_flame_hud.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('WinStreakFlameHud qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => WinStreakFlameHud(streakCount: 5, multiplierLabel: 'x3'),
      guidelines: const [],
    );
  });
}
