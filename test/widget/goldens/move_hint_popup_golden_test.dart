import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/move_hint_popup.dart';
import '../../support/golden_matrix.dart';

void main() {
  testWidgets('MoveHintPopup qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => MoveHintPopup(
        type: MoveHintType.swap,
        title: 'Swap Tiles',
        message: 'Swap adjacent gems to complete the weekly goal.',
        remainingHints: 2,
        onDismiss: () {},
      ),
      guidelines: const [],
    );
  });
}
