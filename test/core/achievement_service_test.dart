import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('AchievementService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(AchievementService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = AchievementService();
      Get.put(service, permanent: true);
      expect(AchievementService.maybe, same(service));
    });

    test('chưa đạt ngưỡng thì isCompleted trả về false', () {
      final service = AchievementService();
      service.register('first_win', 3);

      service.incrementProgress('first_win', 2);

      expect(service.isCompleted('first_win'), false);
    });

    test('tăng progress đủ ngưỡng thì isCompleted trả về true', () {
      final service = AchievementService();
      service.register('first_win', 3);

      service.incrementProgress('first_win', 3);

      expect(service.isCompleted('first_win'), true);
    });

    test(
      'tăng progress vượt ngưỡng nhiều lần không lỗi, không "unlock lại"',
      () {
        final service = AchievementService();
        service.register('first_win', 3);

        service.incrementProgress('first_win', 3);
        expect(service.isCompleted('first_win'), true);

        // Gọi thêm nhiều lần sau khi đã hoàn thành — không được throw,
        // isCompleted phải giữ nguyên true.
        expect(() => service.incrementProgress('first_win', 5), returnsNormally);
        expect(() => service.incrementProgress('first_win', 100), returnsNormally);
        expect(service.isCompleted('first_win'), true);
      },
    );

    test('achievement chưa register thì isCompleted trả về false, không throw', () {
      final service = AchievementService();
      expect(() => service.isCompleted('unknown'), returnsNormally);
      expect(service.isCompleted('unknown'), false);
    });

    test('incrementProgress cộng dồn đúng qua nhiều lần gọi', () {
      final service = AchievementService();
      service.register('collect_10', 10);

      service.incrementProgress('collect_10', 4);
      service.incrementProgress('collect_10', 4);
      expect(service.isCompleted('collect_10'), false);

      service.incrementProgress('collect_10', 2);
      expect(service.isCompleted('collect_10'), true);
    });

    test('progress persist qua restart (instance mới đọc lại từ StorageService)', () {
      final service1 = AchievementService();
      service1.register('first_win', 3);
      service1.incrementProgress('first_win', 3);
      expect(service1.isCompleted('first_win'), true);

      // "Restart": instance mới, cùng StorageService đã Get.put ở setUp.
      final service2 = AchievementService();
      service2.register('first_win', 3);
      expect(service2.isCompleted('first_win'), true);
    });

    test('progress chưa đủ ngưỡng cũng persist đúng qua restart', () {
      final service1 = AchievementService();
      service1.register('first_win', 3);
      service1.incrementProgress('first_win', 1);

      final service2 = AchievementService();
      service2.register('first_win', 3);
      service2.incrementProgress('first_win', 1);

      expect(service2.isCompleted('first_win'), false);
      service2.incrementProgress('first_win', 1);
      expect(service2.isCompleted('first_win'), true);
    });
  });
}
