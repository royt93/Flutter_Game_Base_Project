import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/wake_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('WakeLockService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(WakeLockService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = WakeLockService();
      Get.put(service, permanent: true);
      expect(WakeLockService.maybe, same(service));
    });

    test('enabled mặc định true trước khi init() đọc storage', () {
      final service = WakeLockService();
      expect(service.enabled.value, true);
    });

    test('init() đọc lại giá trị false đã lưu trước đó', () async {
      await store.setBool(StorageKeys.wakeLockEnabled, false);
      final service = WakeLockService();

      await service.init();

      expect(service.enabled.value, false);
    });

    test(
      'init() không throw khi chưa có giá trị nào được lưu (fallback true)',
      () async {
        final service = WakeLockService();

        await service.init();

        expect(service.enabled.value, true);
        expect(store.getBool(StorageKeys.wakeLockEnabled, def: true), true);
      },
    );

    test('setEnabled(false) đảo enabled và persist qua StorageKeys', () async {
      final service = WakeLockService();

      await service.setEnabled(false);

      expect(service.enabled.value, false);
      expect(store.getBool(StorageKeys.wakeLockEnabled, def: true), false);
    });

    test('setEnabled với cùng giá trị hiện tại là no-op', () async {
      final service = WakeLockService();
      expect(service.enabled.value, true);

      await service.setEnabled(true);

      expect(service.enabled.value, true);
    });

    test('toggle() đảo enabled qua lại đúng chiều', () async {
      final service = WakeLockService();

      await service.toggle();
      expect(service.enabled.value, false);

      await service.toggle();
      expect(service.enabled.value, true);
    });

    test('không throw khi platform wakelock không khả dụng (test env)', () {
      final service = WakeLockService();
      expect(() => service.init(), returnsNormally);
      expect(() => service.setEnabled(false), returnsNormally);
    });
  });
}
