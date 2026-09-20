import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _run(List<String> args) =>
    Process.run('dart', ['run', 'tool/performance_budget_check.dart', ...args]);

void main() {
  group('CLI: check trên chính policy/baseline thật của repo', () {
    test(
      'check (không --device) pass nhờ baseline realDevice đã commit sẵn',
      () async {
        final result = await _run(['check']);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final output = result.stdout as String;
        expect(output, contains('object_pool_allocation_reduction_percent'));
        expect(output, contains('example_app_boot_wall_ms'));
        expect(output, contains('Performance budget: PASS'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('CLI: policy/baseline tuỳ chỉnh qua temp file', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('perf_budget_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('thiếu baseline realDevice -> missingMeasurement, exit 1', () async {
      final policyPath = '${tempDir.path}/policy.json';
      File(policyPath).writeAsStringSync(
        jsonEncode([
          {
            'metricName': 'example_app_boot_wall_ms',
            'requiredSource': 'realDevice',
            'direction': 'atMost',
            'limit': 60000.0,
          },
        ]),
      );

      final result = await _run([
        'check',
        '--policies=$policyPath',
        '--baseline=${tempDir.path}/no_such_baseline.json',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('missingMeasurement'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('budget host quá chặt so với thực đo -> budgetExceeded, exit 1', () async {
      final policyPath = '${tempDir.path}/policy.json';
      File(policyPath).writeAsStringSync(
        jsonEncode([
          {
            'metricName': 'object_pool_allocation_reduction_percent',
            'requiredSource': 'hostHeadless',
            'direction': 'atLeast',
            'limit': 99.99,
          },
        ]),
      );

      final result = await _run([
        'check',
        '--policies=$policyPath',
        '--baseline=${tempDir.path}/no_such_baseline.json',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('budgetExceeded'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('policy JSON có entry hỏng -> bỏ qua entry đó, không crash', () async {
      final policyPath = '${tempDir.path}/policy.json';
      File(policyPath).writeAsStringSync(
        jsonEncode([
          'not a map',
          {
            'metricName': 'object_pool_allocation_reduction_percent',
            'requiredSource': 'hostHeadless',
            'direction': 'atLeast',
            'limit': 0.0,
          },
        ]),
      );

      final result = await _run([
        'check',
        '--policies=$policyPath',
        '--baseline=${tempDir.path}/no_such_baseline.json',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('snapshot (không --device) ghi đúng 2 metric hostHeadless, giữ '
        'nguyên metric realDevice cũ đã có trong baseline', () async {
      final baselinePath = '${tempDir.path}/baseline.json';
      File(baselinePath).writeAsStringSync(
        jsonEncode([
          {
            'name': 'example_app_boot_wall_ms',
            'source': 'realDevice',
            'value': 12345.0,
            'unit': 'ms',
            'recordedAtMs': 1000,
          },
        ]),
      );

      final result = await _run(['snapshot', '--baseline=$baselinePath']);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final written =
          jsonDecode(File(baselinePath).readAsStringSync()) as List<Object?>;
      expect(written, hasLength(3));
      final byName = {
        for (final entry in written.cast<Map<String, Object?>>())
          entry['name'] as String: entry,
      };
      expect(byName['object_pool_allocation_reduction_percent']!['value'], 97.5);
      expect(byName['object_pool_pooled_elapsed_us'], isNotNull);
      // realDevice metric không được đo lại (không --device) -> giữ nguyên
      // giá trị cũ, không bị ghi đè thành 0/null.
      expect(byName['example_app_boot_wall_ms']!['value'], 12345.0);
      expect(byName['example_app_boot_wall_ms']!['recordedAtMs'], 1000);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
