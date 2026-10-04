import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/runtime_flags.dart';

void main() {
  test('IDEA-71: isE2eTest mặc định false khi test runner không truyền '
      '--dart-define=E2E_TEST=true (an toàn by default, không phụ thuộc '
      'platform channel)', () {
    expect(isE2eTest, isFalse);
  });
}
