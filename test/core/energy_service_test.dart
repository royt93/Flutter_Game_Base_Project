import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('EnergyService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(EnergyService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = EnergyService();
      Get.put(service, permanent: true);
      expect(EnergyService.maybe, same(service));
    });

    test('mặc định đầy tim khi chưa có gì lưu trước đó', () {
      final service = EnergyService(maxEnergy: 5);
      expect(service.currentEnergy, 5);
    });

    test('consumeEnergy trừ đúng số lượng và trả về true khi đủ tim', () {
      final service = EnergyService(maxEnergy: 5);

      expect(service.consumeEnergy(), true);
      expect(service.currentEnergy, 4);

      expect(service.consumeEnergy(2), true);
      expect(service.currentEnergy, 2);
    });

    test('consumeEnergy trả về false và KHÔNG trừ khi không đủ tim', () {
      final service = EnergyService(maxEnergy: 3);

      expect(service.consumeEnergy(3), true);
      expect(service.currentEnergy, 0);

      expect(service.consumeEnergy(1), false);
      expect(service.currentEnergy, 0, reason: 'không đủ thì không được trừ');
    });

    test(
      'tim tự hồi đúng số lượng sau khi mô phỏng trôi qua N phút',
      () {
        final service = EnergyService(
          maxEnergy: 5,
          refillInterval: const Duration(minutes: 30),
        );

        // Trừ 3 tim -> baseline hồi tim bắt đầu tính từ đây.
        expect(service.consumeEnergy(3), true);
        expect(service.currentEnergy, 2);

        // Mô phỏng "đóng app -> mở lại sau 30 phút" bằng cách đẩy mốc
        // nowMsClamped() đọc/kẹp vào (StorageKeys.maxMsSeen) tiến lên, thay vì
        // chờ Future.delayed thật.
        store.setInt(StorageKeys.maxMsSeen, _realMs + 30 * 60 * 1000);
        expect(service.currentEnergy, 3, reason: 'hồi đúng 1 tim sau 30 phút');

        // Tiến thêm 65 phút nữa (tổng ~95 phút từ lúc trừ tim) -> hồi thêm 2
        // tim nữa (3 tick trọn vẹn), tổng phải đầy lại (max = 5), không vượt.
        store.setInt(StorageKeys.maxMsSeen, _realMs + 95 * 60 * 1000);
        expect(service.currentEnergy, 5, reason: 'hồi đủ và không vượt max');
      },
    );

    test(
      'chỉnh lùi mốc thời gian trực tiếp không làm tim tụt lại hay tăng khống',
      () {
        final service = EnergyService(
          maxEnergy: 5,
          refillInterval: const Duration(minutes: 30),
        );

        expect(service.consumeEnergy(2), true);
        store.setInt(StorageKeys.maxMsSeen, _realMs + 30 * 60 * 1000);
        expect(service.currentEnergy, 4);

        // Cố tình ghi thẳng một mốc "quá khứ" vào StorageKeys.maxMsSeen để mô
        // phỏng hành vi chỉnh lùi đồng hồ máy. nowMsClamped() tự kẹp lại theo
        // mốc lớn nhất từng thấy nên không farm thêm được tim.
        store.setInt(StorageKeys.maxMsSeen, _realMs - 999999999);
        expect(
          service.currentEnergy,
          4,
          reason: 'không được tụt lại và cũng không được hồi thêm khống',
        );
      },
    );

    test(
      'grantInfiniteLives: consumeEnergy luôn thành công và không trừ tim',
      () {
        final service = EnergyService(maxEnergy: 3);
        expect(service.consumeEnergy(3), true);
        expect(service.currentEnergy, 0);

        service.grantInfiniteLives(const Duration(minutes: 10));
        expect(service.hasInfiniteLives, true);

        expect(service.consumeEnergy(1), true);
        expect(
          service.currentEnergy,
          0,
          reason: 'infinite lives không cộng dồn tim, chỉ cho phép tiêu thoải mái',
        );
      },
    );

    test('grantInfiniteLives hết hạn thì lại trừ tim bình thường', () {
      final service = EnergyService(maxEnergy: 3);
      service.grantInfiniteLives(const Duration(minutes: 10));
      expect(service.hasInfiniteLives, true);

      store.setInt(StorageKeys.maxMsSeen, _realMs + 11 * 60 * 1000);
      expect(service.hasInfiniteLives, false);

      expect(service.consumeEnergy(3), true);
      expect(service.consumeEnergy(1), false, reason: 'hết hạn rồi thì hết tim là thua');
    });
  });
}
