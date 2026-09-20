import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/sdk_health_report.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

void main() {
  tearDown(Get.reset);

  test('không collector nào: vẫn ra report hợp lệ với sections rỗng', () async {
    final report = SdkHealthReport(nowMs: () => 1000);
    final result = await report.collect();

    expect(result['schemaVersion'], SdkHealthReport.schemaVersion);
    expect(result['generatedAtMs'], 1000);
    expect(result['sections'], isEmpty);
  });

  test('chỉ key trong allowlist lọt qua — mặc định TỪ CHỐI key lạ', () async {
    final report = SdkHealthReport(nowMs: () => 0)
      ..register(
        HealthCollectorSpec(
          name: 'test',
          allowedKeys: const {'safe'},
          collect: () => {'safe': 'ok', 'token': 'super-secret'},
        ),
      );

    final result = await report.collect();
    final section = (result['sections'] as Map)['test'] as Map;

    expect(section['safe'], 'ok');
    expect(section.containsKey('token'), isFalse);
  });

  test(
    '1 collector throw: section đó báo lỗi, các collector khác vẫn chạy đủ',
    () async {
      final report = SdkHealthReport(nowMs: () => 0)
        ..register(
          HealthCollectorSpec(
            name: 'broken',
            allowedKeys: const {},
            collect: () => throw Exception('boom'),
          ),
        )
        ..register(
          HealthCollectorSpec(
            name: 'ok',
            allowedKeys: const {'value'},
            collect: () => {'value': 42},
          ),
        );

      final result = await report.collect();
      final sections = result['sections'] as Map;

      expect((sections['broken'] as Map).containsKey('_error'), isTrue);
      expect((sections['ok'] as Map)['value'], 42);
    },
  );

  test(
    'collector quá timeout: bị cô lập thành lỗi, không treo cả report',
    () async {
      final report =
          SdkHealthReport(
            nowMs: () => 0,
            timeout: const Duration(milliseconds: 10),
          )..register(
            HealthCollectorSpec(
              name: 'slow',
              allowedKeys: const {'x'},
              collect: () async {
                await Future<void>.delayed(const Duration(seconds: 5));
                return {'x': 1};
              },
            ),
          );

      final result = await report.collect();
      final section = (result['sections'] as Map)['slow'] as Map;

      expect(section.containsKey('_error'), isTrue);
    },
  );

  test('string dài bị cắt, không phình report vô hạn', () async {
    final report = SdkHealthReport(nowMs: () => 0, maxStringLength: 10)
      ..register(
        HealthCollectorSpec(
          name: 'test',
          allowedKeys: const {'text'},
          collect: () => {'text': 'x' * 1000},
        ),
      );

    final result = await report.collect();
    final text = ((result['sections'] as Map)['test'] as Map)['text'] as String;

    expect(text.length, lessThan(1000));
  });

  test('list dài bị cắt', () async {
    final report = SdkHealthReport(nowMs: () => 0, maxListLength: 3)
      ..register(
        HealthCollectorSpec(
          name: 'test',
          allowedKeys: const {'items'},
          collect: () => {'items': List.generate(100, (i) => i)},
        ),
      );

    final result = await report.collect();
    final items = ((result['sections'] as Map)['test'] as Map)['items'] as List;

    expect(items.length, lessThanOrEqualTo(4)); // 3 + 1 dòng "…N more"
  });

  test('giá trị nhỏ bình thường không bị đụng tới', () async {
    final report = SdkHealthReport(nowMs: () => 0)
      ..register(
        HealthCollectorSpec(
          name: 'test',
          allowedKeys: const {'ok'},
          collect: () => {'ok': 'short'},
        ),
      );

    final result = await report.collect();
    expect(((result['sections'] as Map)['test'] as Map)['ok'], 'short');
  });

  test('collectJson(): JSON hợp lệ, decode lại đúng', () async {
    final report = SdkHealthReport(nowMs: () => 5)
      ..register(
        HealthCollectorSpec(
          name: 'test',
          allowedKeys: const {'ok'},
          collect: () => {'ok': true},
        ),
      );

    final jsonStr = await report.collectJson();
    final decoded = jsonDecode(jsonStr) as Map;

    expect(decoded['generatedAtMs'], 5);
    expect((decoded['sections'] as Map)['test']['ok'], true);
  });

  group('defaultHealthCollectors', () {
    test(
      'không service nào đăng ký: mọi section báo registered=false, không crash',
      () async {
        final report = SdkHealthReport(nowMs: () => 0)
          ..registerAll(defaultHealthCollectors());

        final result = await report.collect();
        final sections = result['sections'] as Map;

        expect((sections['audio'] as Map)['registered'], isFalse);
        expect((sections['replayBuffer'] as Map)['registered'], isFalse);
      },
    );

    test(
      'có AudioManager/ReplayRecorder đăng ký: phản ánh đúng state thật',
      () async {
        Get.put<StorageService>(StorageService(null));
        final audio = AudioManager()..muted.value = true;
        Get.put<AudioManager>(audio);
        final recorder = ReplayRecorder()..start(seed: 1);
        Get.put<ReplayRecorder>(recorder);

        final report = SdkHealthReport(nowMs: () => 0)
          ..registerAll(defaultHealthCollectors());
        final result = await report.collect();
        final sections = result['sections'] as Map;

        expect((sections['audio'] as Map)['registered'], isTrue);
        expect((sections['audio'] as Map)['muted'], isTrue);
        expect((sections['replayBuffer'] as Map)['registered'], isTrue);
        expect((sections['replayBuffer'] as Map)['isRecording'], isTrue);
      },
    );
  });
}
