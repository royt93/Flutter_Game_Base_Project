import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/offline_earnings_popup.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('OfflineEarningsPopup qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => OfflineEarningsPopup(
        coins: 12345,
        elapsed: const Duration(days: 2, hours: 5),
        ratePerSecond: 0.125,
        onCollect: () {},
        onDoubleTap: () {},
      ),
      guidelines: const [],
    );
  });
}
