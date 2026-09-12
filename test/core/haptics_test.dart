import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hapticLevelForGroupSize (I11 — rung theo cỡ nhóm nổ)', () {
    test('nhóm nhỏ (<4) → light', () {
      expect(hapticLevelForGroupSize(2), HapticLevel.light);
      expect(hapticLevelForGroupSize(3), HapticLevel.light);
    });

    test('nhóm vừa (4..7) → medium', () {
      expect(hapticLevelForGroupSize(4), HapticLevel.medium);
      expect(hapticLevelForGroupSize(7), HapticLevel.medium);
    });

    test('nhóm lớn (>=8) → heavy', () {
      expect(hapticLevelForGroupSize(8), HapticLevel.heavy);
      expect(hapticLevelForGroupSize(20), HapticLevel.heavy);
    });
  });

  group('fireHaptic (ENH-36)', () {
    final calls = <MethodCall>[];
    late StorageService store;

    setUp(() async {
      calls.clear();
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
      Get.put(store, permanent: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      Get.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('hapticsEnabled == false → không gọi platform method nào', () async {
      await store.setBool(StorageKeys.hapticsEnabled, false);
      fireHaptic(HapticLevel.heavy);
      await Future<void>.delayed(Duration.zero);

      expect(calls, isEmpty);
    });

    test('hapticsEnabled chưa từng set (mặc định true) → vẫn gọi platform method', () async {
      fireHaptic(HapticLevel.light);
      await Future<void>.delayed(Duration.zero);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'HapticFeedback.vibrate');
    });

    test('mỗi HapticLevel map đúng platform method ở chế độ thường (không soft mode)', () async {
      await store.setBool(StorageKeys.hapticsEnabled, true);
      const expected = {
        HapticLevel.light: 'HapticFeedbackType.lightImpact',
        HapticLevel.medium: 'HapticFeedbackType.mediumImpact',
        HapticLevel.heavy: 'HapticFeedbackType.heavyImpact',
      };

      for (final entry in expected.entries) {
        calls.clear();
        fireHaptic(entry.key);
        await Future<void>.delayed(Duration.zero);

        expect(calls, hasLength(1), reason: '${entry.key}');
        expect(calls.single.arguments, entry.value);
      }
    });

    test(
      'soft mode bật → downgrade đúng 1 bậc trước khi map '
      '(heavy→medium, medium→light, light→light giữ nguyên)',
      () async {
        await store.setBool(StorageKeys.hapticsEnabled, true);
        await store.setBool(StorageKeys.hapticSoftMode, true);
        const expected = {
          HapticLevel.heavy: 'HapticFeedbackType.mediumImpact',
          HapticLevel.medium: 'HapticFeedbackType.lightImpact',
          HapticLevel.light: 'HapticFeedbackType.lightImpact',
        };

        for (final entry in expected.entries) {
          calls.clear();
          fireHaptic(entry.key);
          await Future<void>.delayed(Duration.zero);

          expect(calls.single.arguments, entry.value, reason: '${entry.key}');
        }
      },
    );
  });
}
