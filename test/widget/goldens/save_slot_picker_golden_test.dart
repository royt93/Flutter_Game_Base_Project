import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/presentation/widgets/common/save_slot_picker.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('SaveSlotPicker qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await runGoldenMatrix(
      tester,
      (context) => SaveSlotPicker(
        slots: [
          SaveSlotMeta(
            id: 'slot_1',
            displayName: 'Campaign One',
            createdAtMs: now - 86400000,
            lastPlayedAtMs: now - 3600000,
          ),
          SaveSlotMeta(
            id: 'slot_2',
            displayName: 'A Very Long Campaign Name For Overflow Checks',
            createdAtMs: now - 172800000,
            lastPlayedAtMs: now - 172800000,
          ),
        ],
        activeSlotId: 'slot_1',
        maxSlots: 3,
        onSelect: (_) {},
        onCreate: () {},
        onDelete: (_) {},
      ),
      guidelines: const [],
    );
  });
}
