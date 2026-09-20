import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/diagnostics_export_bundle.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/sdk_health_report.dart';

void main() {
  SdkHealthReport healthWith(Map<String, Object?> data, Set<String> allowed) {
    final report = SdkHealthReport(nowMs: () => 1000);
    report.register(
      HealthCollectorSpec(name: 'app', allowedKeys: allowed, collect: () => data),
    );
    return report;
  }

  group('build: manifest cơ bản', () {
    test('có đúng schemaVersion/generatedAtMs/appVersion, section null bị bỏ qua hẳn', () async {
      final bundle = DiagnosticsExportBundle(nowMs: () => 42);
      final result = await bundle.build(appVersion: '1.2.3');

      expect(result['schemaVersion'], 1);
      expect(result['generatedAtMs'], 42);
      expect(result['appVersion'], '1.2.3');
      expect(result['truncated'], isFalse);
      expect(result['sections'], isEmpty);
      expect(result['errors'], isEmpty);
    });

    test('4 section đều có mặt khi truyền đủ ingredient', () async {
      final bundle = DiagnosticsExportBundle();
      final health = healthWith({'version': '1.0'}, {'version'});
      final replay = ReplayCapsule(
        seed: 7,
        appVersion: '1.0',
        events: const [ReplayEvent(offsetMs: 0, type: 'tap', payload: {})],
      );

      final result = await bundle.build(
        appVersion: '1.0',
        health: health,
        replay: replay,
        config: const {'difficulty': 'hard'},
        configAllowedKeys: const {'difficulty'},
        logs: const ['line 1', 'line 2'],
      );

      final sections = result['sections'] as Map;
      expect(sections.keys, containsAll(['health', 'replay', 'config', 'logs']));
    });
  });

  group('build: redaction default-deny cho config', () {
    test('không truyền configAllowedKeys -> config section rỗng, không leak gì', () async {
      final bundle = DiagnosticsExportBundle();
      final result = await bundle.build(
        appVersion: '1.0',
        config: const {'apiKey': 'super-secret', 'difficulty': 'hard'},
      );
      final sections = result['sections'] as Map;
      expect(sections['config'], isEmpty);
    });

    test('chỉ định đúng allowedKeys -> chỉ key đó lọt qua, key khác (secret) bị loại', () async {
      final bundle = DiagnosticsExportBundle();
      final result = await bundle.build(
        appVersion: '1.0',
        config: const {'apiKey': 'super-secret', 'difficulty': 'hard'},
        configAllowedKeys: const {'difficulty'},
      );
      final config = (result['sections'] as Map)['config'] as Map;
      expect(config, {'difficulty': 'hard'});
      expect(config.containsKey('apiKey'), isFalse);
    });

    test('config == null -> không có section config nào cả (khác với section rỗng)', () async {
      final bundle = DiagnosticsExportBundle();
      final result = await bundle.build(appVersion: '1.0');
      final sections = result['sections'] as Map;
      expect(sections.containsKey('config'), isFalse);
    });
  });

  group('build: logs — tail + cap độ dài dòng', () {
    test('quá maxLogLines -> chỉ giữ N dòng GẦN NHẤT (tail, không phải head)', () async {
      final bundle = DiagnosticsExportBundle();
      final logs = List.generate(300, (i) => 'log $i');
      final result = await bundle.build(
        appVersion: '1.0',
        logs: logs,
        maxLogLines: 200,
      );
      final kept = (result['sections'] as Map)['logs'] as List;
      expect(kept, hasLength(200));
      expect(kept.first, 'log 100');
      expect(kept.last, 'log 299');
    });

    test('dòng quá dài bị cắt kèm marker …(truncated)', () async {
      final bundle = DiagnosticsExportBundle();
      final longLine = 'x' * 600;
      final result = await bundle.build(
        appVersion: '1.0',
        logs: [longLine],
        maxLogLineLength: 500,
      );
      final kept = (result['sections'] as Map)['logs'] as List;
      expect(kept.single, endsWith('…(truncated)'));
      expect((kept.single as String).length, lessThan(longLine.length));
    });
  });

  group('build: size cap — export lỗi một phần vẫn đọc được phần còn lại', () {
    test('vượt maxBytes -> drop logs trước, replay/config/health vẫn còn nếu đủ nhỏ', () async {
      final bundle = DiagnosticsExportBundle(maxBytes: 400);
      final health = healthWith({'version': '1.0'}, {'version'});
      final result = await bundle.build(
        appVersion: '1.0',
        health: health,
        logs: List.generate(200, (i) => 'a very long log line number $i ' * 5),
      );

      expect(result['truncated'], isTrue);
      final sections = result['sections'] as Map;
      expect(sections.containsKey('logs'), isFalse, reason: 'logs bị drop trước tiên');
      expect(sections.containsKey('health'), isTrue, reason: 'health giữ lại lâu nhất');
      final errors = result['errors'] as Map;
      expect(errors['logs'], contains('dropped'));
    });

    test('thứ tự drop cố định: logs -> replay -> config, health luôn giữ lại cuối cùng', () async {
      final bundle = DiagnosticsExportBundle(maxBytes: 200);
      final health = healthWith({'version': '1.0'}, {'version'});
      final replay = ReplayCapsule(
        seed: 1,
        appVersion: '1.0',
        events: List.generate(
          50,
          (i) => ReplayEvent(offsetMs: i, type: 'tap', payload: {'x': i}),
        ),
      );
      final result = await bundle.build(
        appVersion: '1.0',
        health: health,
        replay: replay,
        config: const {'a': 'b'},
        configAllowedKeys: const {'a'},
        logs: List.generate(100, (i) => 'line $i ' * 10),
      );

      final sections = result['sections'] as Map;
      expect(sections.containsKey('logs'), isFalse);
      expect(sections.containsKey('replay'), isFalse);
      expect(sections.containsKey('config'), isFalse);
      expect(sections.containsKey('health'), isTrue);
    });

    test('bundle rất nhỏ, health tự nó cũng vượt cap -> vẫn không throw, ghi lỗi bundle', () async {
      final bundle = DiagnosticsExportBundle(maxBytes: 5);
      final health = healthWith({'version': '1.0'}, {'version'});
      final result = await bundle.build(appVersion: '1.0', health: health);
      expect(result['truncated'], isTrue);
      expect((result['errors'] as Map)['bundle'], contains('still exceeds'));
    });
  });

  group('sign / DiagnosticsBundleView: round-trip + read-only', () {
    test('build -> sign -> fromSignedJson khớp lại đúng mọi field', () async {
      final bundle = DiagnosticsExportBundle(nowMs: () => 999);
      final health = healthWith({'version': '2.0'}, {'version'});
      final built = await bundle.build(
        appVersion: '2.0',
        health: health,
        config: const {'difficulty': 'easy'},
        configAllowedKeys: const {'difficulty'},
        logs: const ['boot ok'],
      );
      final signed = bundle.sign(built, 'my-secret');
      final view = DiagnosticsBundleView.fromSignedJson(signed, 'my-secret');

      expect(view, isNotNull);
      expect(view!.schemaVersion, 1);
      expect(view.generatedAtMs, 999);
      expect(view.appVersion, '2.0');
      expect(view.truncated, isFalse);
      expect(view.health, {
        'schemaVersion': 1,
        'generatedAtMs': 1000,
        'sections': {
          'app': {'version': '2.0'},
        },
      });
      expect(view.config, {'difficulty': 'easy'});
      expect(view.logs, ['boot ok']);
      expect(view.replay, isNull);
    });

    test('sai secret -> throw FormatException, không âm thầm trả dữ liệu sai', () async {
      final bundle = DiagnosticsExportBundle();
      final built = await bundle.build(appVersion: '1.0');
      final signed = bundle.sign(built, 'right-secret');
      expect(
        () => DiagnosticsBundleView.fromSignedJson(signed, 'wrong-secret'),
        throwsFormatException,
      );
    });

    test('fromJson với map rác (thiếu "sections") -> null, không throw', () {
      expect(DiagnosticsBundleView.fromJson({'foo': 'bar'}), isNull);
    });

    test('parse không đụng tới bất kỳ state/service nào khác (thuần đọc)', () async {
      // Không có StorageService/Get.put nào được setup trong test này —
      // nếu fromJson/fromSignedJson lỡ tay đụng vào 1 service chưa đăng ký
      // (Get.find) test này sẽ throw ngay, chứng minh nó thực sự không.
      final bundle = DiagnosticsExportBundle();
      final built = await bundle.build(appVersion: '1.0', logs: const ['a']);
      final view = DiagnosticsBundleView.fromJson(built);
      expect(view, isNotNull);
      expect(view!.logs, ['a']);
    });
  });
}
