import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_info.dart';

void main() {
  test('kAppName/kCopyright/kAppVersion có giá trị hợp lệ', () {
    expect(kAppName, isNotEmpty);
    expect(kCopyright, isNotEmpty);
    expect(kAppVersion, matches(RegExp(r'^\d{4}\.\d{2}\.\d{2}$')));
  });
}
