import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/platform_capability_registry.dart';

void main() {
  tearDown(Get.reset);

  group(
    'detectPlatformCapabilities: device matrix (fake isWeb/targetPlatform)',
    () {
      test('Android, không phải web: đầy đủ 4 capability', () {
        final snapshot = detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        );

        expect(snapshot.platformKind, PlatformKind.android);
        expect(snapshot.supportsHaptics, isTrue);
        expect(snapshot.supportsShaders, isTrue);
        expect(snapshot.supportsNotifications, isTrue);
        expect(snapshot.supportsBackgroundAudio, isTrue);
      });

      test('iOS, không phải web: đầy đủ 4 capability', () {
        final snapshot = detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
        );

        expect(snapshot.platformKind, PlatformKind.ios);
        expect(snapshot.supportsHaptics, isTrue);
        expect(snapshot.supportsShaders, isTrue);
        expect(snapshot.supportsNotifications, isTrue);
        expect(snapshot.supportsBackgroundAudio, isTrue);
      });

      test(
        'Web (bất kể targetPlatform bên dưới): cả 4 capability đều false',
        () {
          final snapshot = detectPlatformCapabilities(
            isWeb: true,
            targetPlatform: TargetPlatform.android,
          );

          expect(snapshot.platformKind, PlatformKind.web);
          expect(snapshot.supportsHaptics, isFalse);
          expect(snapshot.supportsShaders, isFalse);
          expect(snapshot.supportsNotifications, isFalse);
          expect(snapshot.supportsBackgroundAudio, isFalse);
        },
      );

      test(
        'Windows: shader/notification/backgroundAudio true, haptics false',
        () {
          final snapshot = detectPlatformCapabilities(
            isWeb: false,
            targetPlatform: TargetPlatform.windows,
          );

          expect(snapshot.platformKind, PlatformKind.windows);
          expect(snapshot.supportsHaptics, isFalse);
          expect(snapshot.supportsShaders, isTrue);
          expect(snapshot.supportsNotifications, isTrue);
          expect(snapshot.supportsBackgroundAudio, isTrue);
        },
      );

      test('macOS: giống chính sách desktop khác', () {
        final snapshot = detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
        );

        expect(snapshot.platformKind, PlatformKind.macos);
        expect(snapshot.supportsHaptics, isFalse);
        expect(snapshot.supportsShaders, isTrue);
      });

      test('Linux: giống chính sách desktop khác', () {
        final snapshot = detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.linux,
        );

        expect(snapshot.platformKind, PlatformKind.linux);
        expect(snapshot.supportsHaptics, isFalse);
      });

      test('Fuchsia: map đúng platformKind riêng, không rơi vào unknown', () {
        final snapshot = detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.fuchsia,
        );

        expect(snapshot.platformKind, PlatformKind.fuchsia);
      });

      test(
        'không truyền gì: dùng đúng kIsWeb/defaultTargetPlatform thật của môi trường test',
        () {
          final snapshot = detectPlatformCapabilities();

          expect(snapshot.platformKind, isNotNull);
        },
      );
    },
  );

  group('PlatformCapabilityRegistry: SSOT, cache, không platform channel', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(PlatformCapabilityRegistry.maybe, isNull);
    });

    test(
      'snapshot được tính 1 lần lúc construct, expose lại y hệt mỗi lần đọc',
      () {
        final registry = PlatformCapabilityRegistry(
          snapshot: detectPlatformCapabilities(
            isWeb: false,
            targetPlatform: TargetPlatform.android,
          ),
        );

        final first = registry.snapshot;
        final second = registry.snapshot;

        expect(identical(first, second), isTrue);
        expect(first.platformKind, PlatformKind.android);
      },
    );

    test(
      'inject snapshot thẳng (override auto-detect) cho test/consumer tự quyết định',
      () {
        const forced = PlatformCapabilitySnapshot(
          platformKind: PlatformKind.web,
          supportsHaptics: true, // consumer tự biết rõ hơn policy mặc định
          supportsShaders: false,
          supportsNotifications: false,
          supportsBackgroundAudio: false,
        );
        final registry = PlatformCapabilityRegistry(snapshot: forced);

        expect(registry.snapshot.supportsHaptics, isTrue);
      },
    );

    test('Get.put đúng instance, maybe tìm lại được', () {
      final registry = PlatformCapabilityRegistry(
        snapshot: detectPlatformCapabilities(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
        ),
      );
      Get.put(registry, permanent: true);

      expect(PlatformCapabilityRegistry.maybe, same(registry));
    });
  });

  group(
    'PlatformCapabilityRegistry.withFallback: chính sách fallback rõ ràng, không crash',
    () {
      test('supported = true: chạy nhánh ifSupported', () {
        final registry = PlatformCapabilityRegistry(
          snapshot: detectPlatformCapabilities(
            isWeb: false,
            targetPlatform: TargetPlatform.android,
          ),
        );

        final result = registry.withFallback<String>(
          supported: true,
          ifSupported: () => 'native',
          fallback: () => 'fallback',
        );

        expect(result, 'native');
      });

      test('supported = false: chạy nhánh fallback, không throw', () {
        final registry = PlatformCapabilityRegistry(
          snapshot: detectPlatformCapabilities(isWeb: true),
        );

        final result = registry.withFallback<String>(
          supported: registry.snapshot.supportsHaptics,
          ifSupported: () => 'native',
          fallback: () => 'noop',
        );

        expect(result, 'noop');
      });

      test(
        'ifSupported ném lỗi không bị withFallback nuốt (không che giấu bug thật)',
        () {
          final registry = PlatformCapabilityRegistry(
            snapshot: detectPlatformCapabilities(
              isWeb: false,
              targetPlatform: TargetPlatform.android,
            ),
          );

          expect(
            () => registry.withFallback<void>(
              supported: true,
              ifSupported: () => throw StateError('boom'),
              fallback: () {},
            ),
            throwsStateError,
          );
        },
      );
    },
  );
}
