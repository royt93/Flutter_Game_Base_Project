import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_version_gate.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('compareAppVersions: policy prerelease/build (semver)', () {
    test('so sánh core version khác nhau', () {
      expect(compareAppVersions('1.2.3', '1.2.4'), lessThan(0));
      expect(compareAppVersions('1.3.0', '1.2.9'), greaterThan(0));
    });

    test('version bằng nhau: 0', () {
      expect(compareAppVersions('1.2.3', '1.2.3'), 0);
    });

    test('prerelease THẤP HƠN cùng core không prerelease', () {
      expect(compareAppVersions('1.2.3-beta', '1.2.3'), lessThan(0));
    });

    test('build metadata bị BỎ QUA hoàn toàn khi so sánh', () {
      expect(compareAppVersions('1.2.3+001', '1.2.3+999'), 0);
    });

    test('version không parse được (invalid): trả về null', () {
      expect(compareAppVersions('not-a-version', '1.2.3'), isNull);
      expect(compareAppVersions('1.2.3', 'also-invalid'), isNull);
    });
  });

  group('evaluateVersionGate: quyết định gate', () {
    test('maintenanceActive: luôn maintenance bất kể version', () {
      final decision = evaluateVersionGate(
        currentVersion: '9.9.9',
        config: const AppVersionGateConfig(maintenanceActive: true),
      );
      expect(decision, GateDecision.maintenance);
    });

    test('current < minimum: forceUpdate', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.0.0',
        config: const AppVersionGateConfig(minimumVersion: '1.1.0'),
      );
      expect(decision, GateDecision.forceUpdate);
    });

    test('current == minimum: đủ điều kiện, KHÔNG forceUpdate', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.1.0',
        config: const AppVersionGateConfig(minimumVersion: '1.1.0'),
      );
      expect(decision, isNot(GateDecision.forceUpdate));
    });

    test('current >= minimum nhưng < recommended: softUpdate', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.1.0',
        config: const AppVersionGateConfig(
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
      );
      expect(decision, GateDecision.softUpdate);
    });

    test('current >= recommended: ok', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.2.0',
        config: const AppVersionGateConfig(
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
      );
      expect(decision, GateDecision.ok);
    });

    test('minimumVersion invalid (config hỏng): không force, an toàn', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.0.0',
        config: const AppVersionGateConfig(minimumVersion: 'garbage'),
      );
      expect(decision, isNot(GateDecision.forceUpdate));
    });

    test('currentVersion invalid: không force/soft, trả ok (an toàn tuyệt đối)', () {
      final decision = evaluateVersionGate(
        currentVersion: 'garbage',
        config: const AppVersionGateConfig(
          minimumVersion: '5.0.0',
          recommendedVersion: '9.0.0',
        ),
      );
      expect(decision, GateDecision.ok);
    });

    test('config rỗng hoàn toàn: ok', () {
      final decision = evaluateVersionGate(
        currentVersion: '1.0.0',
        config: const AppVersionGateConfig(),
      );
      expect(decision, GateDecision.ok);
    });
  });

  group('AppVersionGateController: dùng RemoteConfigService làm nguồn', () {
    late StorageService store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
      Get.put(store, permanent: true);
    });

    test('RemoteConfigService rỗng (chưa init/asset rỗng): decision ok', () async {
      final remoteConfig = RemoteConfigService(assetPath: 'nonexistent.json');
      await remoteConfig.init();
      final controller = AppVersionGateController(remoteConfig: remoteConfig);

      expect(controller.decisionFor('1.0.0'), GateDecision.ok);
    });

    test('config từ RemoteConfigService map đúng vào GateDecision', () async {
      final remoteConfig = RemoteConfigService(
        assetPath: 'nonexistent.json',
        fetchRemote: () async => {
          'appVersionMinimum': '2.0.0',
          'appVersionRecommended': '3.0.0',
        },
      );
      await remoteConfig.init();
      final controller = AppVersionGateController(remoteConfig: remoteConfig);

      expect(controller.decisionFor('1.0.0'), GateDecision.forceUpdate);
      expect(controller.decisionFor('2.5.0'), GateDecision.softUpdate);
      expect(controller.decisionFor('3.0.0'), GateDecision.ok);
    });

    test('maintenanceActive từ remote: map đúng maintenance + message', () async {
      final remoteConfig = RemoteConfigService(
        assetPath: 'nonexistent.json',
        fetchRemote: () async => {
          'appVersionMaintenanceActive': true,
          'appVersionMaintenanceMessage': 'Bảo trì 2h',
        },
      );
      await remoteConfig.init();
      final controller = AppVersionGateController(remoteConfig: remoteConfig);

      expect(controller.decisionFor('9.9.9'), GateDecision.maintenance);
      expect(controller.config.maintenanceMessage, 'Bảo trì 2h');
    });

    test(
      'recordSoftPromptDismissed() thật sự trả void ở runtime, không phải Future — '
      'an toàn để gọi trong setState(() => ...)',
      () {
        final controller = AppVersionGateController(
          remoteConfig: RemoteConfigService(assetPath: 'nonexistent.json'),
        );

        // Gọi qua `dynamic` để bỏ qua static void check, kiểm tra đúng giá
        // trị trả về THẬT ở runtime — đúng cách `setState()` tự kiểm tra
        // nội bộ (`result is Future`).
        final dynamic call = controller.recordSoftPromptDismissed;
        final dynamic result = call();

        expect(result, isNot(isA<Future>()));
      },
    );

    test('softPromptDue: mặc định true khi chưa từng dismiss', () {
      final controller = AppVersionGateController(
        remoteConfig: RemoteConfigService(assetPath: 'nonexistent.json'),
      );
      expect(controller.softPromptDue, isTrue);
    });

    test('vừa recordSoftPromptDismissed(): chưa due lại ngay', () {
      final controller = AppVersionGateController(
        remoteConfig: RemoteConfigService(assetPath: 'nonexistent.json'),
        softPromptCooldown: const Duration(days: 3),
      );
      controller.recordSoftPromptDismissed();

      expect(controller.softPromptDue, isFalse);
    });

    test('sau khi hết cooldown: due lại', () {
      final controller = AppVersionGateController(
        remoteConfig: RemoteConfigService(assetPath: 'nonexistent.json'),
        softPromptCooldown: const Duration(days: 3),
      );
      controller.recordSoftPromptDismissed();
      store.setInt(
        StorageKeys.maxMsSeen,
        _realMs + const Duration(days: 4).inMilliseconds,
      );

      expect(controller.softPromptDue, isTrue);
    });
  });
}
