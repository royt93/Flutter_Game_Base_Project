import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/remote_kill_switch_controller.dart';
import 'package:roy_casual_kit/core/shadow_activation_controller.dart';

class _EmptyAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw Exception('Asset not found: $key');
  }
}

void main() {
  Future<RemoteKillSwitchController> buildKillSwitch() async {
    final config = RemoteConfigService(
      assetPath: 'does_not_exist.json',
      bundle: _EmptyAssetBundle(),
      fetchRemote: () async => {},
    );
    await config.init();
    return RemoteKillSwitchController(remoteConfig: config);
  }

  test(
    'metric trong ngưỡng cho phép -> KHÔNG rollback, feature vẫn bật',
    () async {
      final killSwitch = await buildKillSwitch();
      final shadow = ShadowActivationController(killSwitch: killSwitch);
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );

      shadow.reportMetric('new_event', 'earn_rate', 50);

      expect(killSwitch.isKilled('new_event'), isFalse);
    },
  );

  test(
    'metric vượt max -> auto-rollback đúng feature, reason ghi rõ lý do '
    '(tên guardrail + giá trị)',
    () async {
      final killSwitch = await buildKillSwitch();
      final shadow = ShadowActivationController(killSwitch: killSwitch);
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );

      shadow.reportMetric('new_event', 'earn_rate', 500);

      expect(killSwitch.isKilled('new_event'), isTrue);
      expect(
        killSwitch.states['new_event']!.source,
        KillSwitchSource.localOverride,
      );
      expect(killSwitch.states['new_event']!.reason, contains('earn_rate'));
      expect(killSwitch.states['new_event']!.reason, contains('500.0'));
    },
  );

  test('metric dưới min -> auto-rollback đúng (vi phạm biên dưới)', () async {
    final killSwitch = await buildKillSwitch();
    final shadow = ShadowActivationController(killSwitch: killSwitch);
    shadow.registerGuardrail(
      'new_event',
      const GuardrailDefinition(metricName: 'spend_rate', min: 10, max: 1000),
    );

    shadow.reportMetric('new_event', 'spend_rate', 2);

    expect(killSwitch.isKilled('new_event'), isTrue);
  });

  test(
    'vi phạm guardrail của 1 feature KHÔNG ảnh hưởng feature khác',
    () async {
      final killSwitch = await buildKillSwitch();
      final shadow = ShadowActivationController(killSwitch: killSwitch);
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );
      shadow.registerGuardrail(
        'other_feature',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );

      shadow.reportMetric('new_event', 'earn_rate', 500);

      expect(killSwitch.isKilled('new_event'), isTrue);
      expect(killSwitch.isKilled('other_feature'), isFalse);
    },
  );

  test(
    'metric type khác (metricName không khớp guardrail nào) -> không rollback',
    () async {
      final killSwitch = await buildKillSwitch();
      final shadow = ShadowActivationController(killSwitch: killSwitch);
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );

      shadow.reportMetric('new_event', 'unrelated_metric', 999999);

      expect(killSwitch.isKilled('new_event'), isFalse);
    },
  );

  test('feature chưa đăng ký guardrail nào -> reportMetric không throw, không rollback', () async {
    final killSwitch = await buildKillSwitch();
    final shadow = ShadowActivationController(killSwitch: killSwitch);

    expect(
      () => shadow.reportMetric('never_registered', 'earn_rate', 999999),
      returnsNormally,
    );
    expect(killSwitch.isKilled('never_registered'), isFalse);
  });

  test(
    'nhiều guardrail cho cùng 1 feature: chỉ cần 1 cái vi phạm là rollback',
    () async {
      final killSwitch = await buildKillSwitch();
      final shadow = ShadowActivationController(killSwitch: killSwitch);
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'earn_rate', min: 0, max: 100),
      );
      shadow.registerGuardrail(
        'new_event',
        const GuardrailDefinition(metricName: 'spend_rate', min: 10, max: 1000),
      );

      shadow.reportMetric('new_event', 'spend_rate', 5); // vi phạm min.

      expect(killSwitch.isKilled('new_event'), isTrue);
    },
  );

  group('GuardrailDefinition', () {
    test('violatedBy đúng cho cả min và max riêng lẻ (1 bound null)', () {
      const maxOnly = GuardrailDefinition(metricName: 'x', max: 100);
      expect(maxOnly.violatedBy(50), isFalse);
      expect(maxOnly.violatedBy(150), isTrue);
      expect(maxOnly.violatedBy(-999), isFalse); // không có min -> không chặn.

      const minOnly = GuardrailDefinition(metricName: 'x', min: 0);
      expect(minOnly.violatedBy(-1), isTrue);
      expect(minOnly.violatedBy(999999), isFalse); // không có max -> không chặn.
    });

    test('thiếu cả min lẫn max -> assert (guardrail vô nghĩa)', () {
      expect(
        () => GuardrailDefinition(metricName: 'x'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
