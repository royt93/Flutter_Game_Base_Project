import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

import '../../support/golden_matrix.dart';

// FEAT-69: demonstrates `runGoldenMatrix` against a real widget kit widget
// (not just the runner's own synthetic fixtures, see
// test/support/golden_matrix_test.dart) — proves it's usable for the
// User story's actual goal ("Tự render widget kit theo theme, locale, RTL,
// text scale và reduced motion"). Deliberately scoped to 1 widget for this
// task rather than all ~47 in the kit — see this task's Quyết định for why
// a full rollout is left as follow-up work, not scope creep here.
void main() {
  testWidgets('CommonButton primary qua toàn bộ ma trận mặc định (7 case)', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => CommonButton(label: 'PLAY', onTap: () {}),
      goldenBaseName: 'common_button_matrix',
    );
  });
}
