import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLI: dart run tool/deprecation_check.dart', () {
    test(
      'registry hiện tại rỗng: exit code 0, báo không có API nào quá hạn',
      () async {
        final result = await Process.run('dart', [
          'run',
          'tool/deprecation_check.dart',
        ]);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('No deprecated API past its removal version.'),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
