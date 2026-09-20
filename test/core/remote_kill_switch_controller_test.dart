import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/remote_kill_switch_controller.dart';

// Không dùng assetPath trỏ tới file không tồn tại + rootBundle thật —
// dưới testWidgets(), PlatformAssetBundle.load treo vô thời hạn thay vì
// throw nhanh như dưới test() thường (phát hiện thật khi viết test này:
// timeout 10 phút). Dùng fake bundle luôn trả lỗi ngay, giống hệt fixture
// đã có sẵn ở test/core/remote_config_service_test.dart.
class _EmptyAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw Exception('Asset not found: $key');
  }
}

void main() {
  Future<RemoteConfigService> configWith(Map<String, Object?> remote) async {
    final service = RemoteConfigService(
      assetPath: 'does_not_exist.json',
      bundle: _EmptyAssetBundle(),
      fetchRemote: () async => remote,
    );
    await service.init();
    return service;
  }

  group('isKilled: giá trị remote hợp lệ', () {
    test('bool true -> killed=true, source=remoteValid', () async {
      final config = await configWith({'kill_switch_shop': true});
      final controller = RemoteKillSwitchController(remoteConfig: config);

      expect(controller.isKilled('shop'), isTrue);
      expect(controller.states['shop']!.source, KillSwitchSource.remoteValid);
    });

    test('bool false -> killed=false, source=remoteValid', () async {
      final config = await configWith({'kill_switch_shop': false});
      final controller = RemoteKillSwitchController(remoteConfig: config);

      expect(controller.isKilled('shop'), isFalse);
      expect(controller.states['shop']!.source, KillSwitchSource.remoteValid);
    });

    test(
      'map đầy đủ {killed, reason, version} -> đọc đúng cả 3 field',
      () async {
        final config = await configWith({
          'kill_switch_shop': {
            'killed': true,
            'reason': 'payment provider down',
            'version': 3,
          },
        });
        final controller = RemoteKillSwitchController(remoteConfig: config);

        controller.isKilled('shop');
        final state = controller.states['shop']!;
        expect(state.killed, isTrue);
        expect(state.reason, 'payment provider down');
        expect(state.version, 3);
        expect(state.source, KillSwitchSource.remoteValid);
      },
    );

    test('map thiếu reason/version -> mặc định "" và 0', () async {
      final config = await configWith({
        'kill_switch_shop': {'killed': true},
      });
      final controller = RemoteKillSwitchController(remoteConfig: config);

      controller.isKilled('shop');
      final state = controller.states['shop']!;
      expect(state.reason, '');
      expect(state.version, 0);
    });
  });

  group('asset default: chưa từng có remote hợp lệ', () {
    test(
      'không có key remote, không có asset default -> killed=false',
      () async {
        final config = await configWith({});
        final controller = RemoteKillSwitchController(remoteConfig: config);

        expect(controller.isKilled('shop'), isFalse);
        expect(
          controller.states['shop']!.source,
          KillSwitchSource.assetDefault,
        );
      },
    );

    test(
      'không có key remote, có asset default killed=true -> dùng asset default',
      () async {
        final config = await configWith({});
        final controller = RemoteKillSwitchController(
          remoteConfig: config,
          assetDefaults: const {'shop': true},
        );

        expect(controller.isKilled('shop'), isTrue);
        expect(
          controller.states['shop']!.source,
          KillSwitchSource.assetDefault,
        );
      },
    );
  });

  group('PHÁT HIỆN THẬT: remote invalid không được mở lại feature đã bị kill', () {
    test('remote hợp lệ killed=true trước, sau đó remote hỏng (sai type) -> '
        'vẫn giữ killed=true từ cache, KHÔNG revert về false', () async {
      var remoteValue = <String, Object?>{'kill_switch_shop': true};
      final config = RemoteConfigService(
        assetPath: 'does_not_exist.json',
        bundle: _EmptyAssetBundle(),
        fetchRemote: () async => remoteValue,
      );
      await config.init();
      final controller = RemoteKillSwitchController(remoteConfig: config);

      expect(controller.isKilled('shop'), isTrue);
      expect(controller.states['shop']!.source, KillSwitchSource.remoteValid);

      // Remote đổi thành giá trị sai type (string thay vì bool) — mô
      // phỏng payload hỏng từ server.
      remoteValue = <String, Object?>{'kill_switch_shop': 'yes'};
      await config.init();

      expect(
        controller.isKilled('shop'),
        isTrue,
        reason: 'không được tự ý mở lại feature',
      );
      expect(
        controller.states['shop']!.source,
        KillSwitchSource.cachedLastKnownGood,
      );
    });

    test(
      'map remote thiếu field "killed" hoặc sai type -> bị từ chối hoàn toàn (không dùng)',
      () async {
        final config = await configWith({
          'kill_switch_shop': {'reason': 'no killed field'},
        });
        final controller = RemoteKillSwitchController(
          remoteConfig: config,
          assetDefaults: const {'shop': false},
        );

        expect(controller.isKilled('shop'), isFalse);
        expect(
          controller.states['shop']!.source,
          KillSwitchSource.assetDefault,
        );
      },
    );

    test(
      'remote là số/string thô (không phải bool/map) -> bị từ chối, dùng asset default',
      () async {
        final config = await configWith({'kill_switch_shop': 42});
        final controller = RemoteKillSwitchController(
          remoteConfig: config,
          assetDefaults: const {'shop': true},
        );

        expect(controller.isKilled('shop'), isTrue);
        expect(
          controller.states['shop']!.source,
          KillSwitchSource.assetDefault,
        );
      },
    );
  });

  group('reactive: states cập nhật đúng cho widget đang watch', () {
    test(
      'isKilled cập nhật states[featureId] ngay, nhiều feature độc lập nhau',
      () async {
        final config = await configWith({
          'kill_switch_shop': true,
          'kill_switch_event': false,
        });
        final controller = RemoteKillSwitchController(remoteConfig: config);

        controller.isKilled('shop');
        controller.isKilled('event');

        expect(controller.states['shop']!.killed, isTrue);
        expect(controller.states['event']!.killed, isFalse);
      },
    );

    test('refreshAll cập nhật đủ mọi feature id truyền vào', () async {
      final config = await configWith({
        'kill_switch_shop': true,
        'kill_switch_event': true,
        'kill_switch_animation': false,
      });
      final controller = RemoteKillSwitchController(remoteConfig: config);

      controller.refreshAll(['shop', 'event', 'animation']);

      expect(
        controller.states.keys,
        containsAll(['shop', 'event', 'animation']),
      );
      expect(controller.states['animation']!.killed, isFalse);
    });
  });

  group('audit log', () {
    test('mỗi lần isKilled ghi thêm 1 entry vào auditLog', () async {
      final config = await configWith({'kill_switch_shop': true});
      final controller = RemoteKillSwitchController(remoteConfig: config);

      controller.isKilled('shop');
      controller.isKilled('shop');
      controller.isKilled('shop');

      expect(controller.auditLog, hasLength(3));
    });

    test('auditLog bị giới hạn (bounded), không phình vô hạn', () async {
      final config = await configWith({'kill_switch_shop': true});
      final controller = RemoteKillSwitchController(remoteConfig: config);

      for (var i = 0; i < 250; i++) {
        controller.isKilled('shop');
      }

      expect(controller.auditLog.length, lessThanOrEqualTo(200));
    });
  });

  group('runIfEnabled: guard chống grant sai', () {
    test('feature bị kill -> callback KHÔNG được gọi, trả về null', () async {
      final config = await configWith({'kill_switch_shop': true});
      final controller = RemoteKillSwitchController(remoteConfig: config);
      var called = false;

      final result = controller.runIfEnabled('shop', () {
        called = true;
        return 'granted';
      });

      expect(called, isFalse);
      expect(result, isNull);
    });

    test(
      'feature không bị kill -> callback được gọi, trả đúng kết quả',
      () async {
        final config = await configWith({'kill_switch_shop': false});
        final controller = RemoteKillSwitchController(remoteConfig: config);

        final result = controller.runIfEnabled('shop', () => 'granted');

        expect(result, 'granted');
      },
    );
  });

  group('maybe: null-safe accessor', () {
    test('trả về null khi chưa đăng ký', () {
      expect(RemoteKillSwitchController.maybe, isNull);
    });
  });

  group('widget đang chạy nhận disable mà không crash', () {
    testWidgets(
      'shop đang mở (Obx watch states), ops kill remote giữa chừng -> UI tự ẩn, không throw',
      (tester) async {
        var remoteValue = <String, Object?>{'kill_switch_shop': false};
        final config = RemoteConfigService(
          assetPath: 'does_not_exist.json',
          bundle: _EmptyAssetBundle(),
          fetchRemote: () async => remoteValue,
        );
        await config.init();
        final controller = RemoteKillSwitchController(remoteConfig: config);
        controller.isKilled('shop');

        await tester.pumpWidget(
          MaterialApp(
            home: Obx(() {
              final killed = controller.states['shop']?.killed ?? false;
              return killed
                  ? const Text('Shop đóng cửa')
                  : const Text('Shop: mua vật phẩm');
            }),
          ),
        );

        expect(find.text('Shop: mua vật phẩm'), findsOneWidget);
        expect(find.text('Shop đóng cửa'), findsNothing);

        // Ops kill switch remote NGAY khi widget đang hiển thị.
        remoteValue = <String, Object?>{'kill_switch_shop': true};
        await config.init();
        controller.isKilled('shop');
        await tester.pump();

        expect(find.text('Shop đóng cửa'), findsOneWidget);
        expect(find.text('Shop: mua vật phẩm'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
