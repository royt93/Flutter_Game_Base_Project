import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runCheck(List<String> args) => Process.run(
  'dart',
  ['run', 'tool/accessibility_audit_check.dart', ...args],
);

void main() {
  group('CLI: dart run tool/accessibility_audit_check.dart trên repo thật', () {
    test(
      'widget kit thật + baseline thật: exit code 0, mọi finding đã suppress có lý do',
      () async {
        final result = await _runCheck([]);
        expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
        expect(result.stdout as String, contains('No accessibility issues found.'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('CLI: fixture --root synthetic bắt lỗi thật', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('accessibility_audit_check_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    void writeFile(String relativePath, String content) {
      final file = File('${tempDir.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('widget lỗi (GestureDetector không Semantics) -> exit code 1, báo đúng file', () async {
      writeFile('widgets/bad.dart', "GestureDetector(onTap: () {}, child: Text('x'))");

      final result = await _runCheck(['--root=${tempDir.path}/widgets']);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('tapTargetSemantics'));
      expect(result.stdout as String, contains('bad.dart'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('widget hợp lệ -> exit code 0, không false fail', () async {
      writeFile(
        'widgets/good.dart',
        "Semantics(button: true, label: 'x', child: GestureDetector(onTap: () {}))",
      );

      final result = await _runCheck(['--root=${tempDir.path}/widgets']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('baseline suppress đúng finding theo file+rule, có lý do', () async {
      writeFile('widgets/bad.dart', "GestureDetector(onTap: () {}, child: Text('x'))");
      writeFile(
        'baseline.json',
        jsonEncode([
          {
            'file': '${tempDir.path}/widgets/bad.dart',
            'rule': 'tapTargetSemantics',
            'reason': 'wrapper chung, đã review',
          },
        ]),
      );

      final result = await _runCheck([
        '--root=${tempDir.path}/widgets',
        '--baseline=${tempDir.path}/baseline.json',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('không có file baseline -> vẫn chạy bình thường (baseline rỗng)', () async {
      writeFile('widgets/ok.dart', 'class Ok extends StatelessWidget {}');

      final result = await _runCheck([
        '--root=${tempDir.path}/widgets',
        '--baseline=${tempDir.path}/no_such_baseline.json',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('--minSeverity=error chỉ fail khi có lỗi mức error, bỏ qua warning', () async {
      writeFile('widgets/warn_only.dart', "GestureDetector(onTap: () {}, child: Text('x'))");

      final result = await _runCheck([
        '--root=${tempDir.path}/widgets',
        '--minSeverity=error',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout as String, contains('1 issue(s) found'));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
