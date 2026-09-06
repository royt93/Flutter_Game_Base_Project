import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/offline_progression_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
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

  /// Giả lập "đã đi vắng [hours] giờ" bằng cách đẩy mốc kẹp đồng hồ
  /// (`StorageKeys.maxMsSeen`, thứ `nowMsClamped()` đọc/kẹp vào) tiến lên
  /// thẳng — không cần chờ đồng hồ thật trôi qua.
  Future<void> advanceHours(double hours) async {
    final current = store.getInt(StorageKeys.maxMsSeen);
    await store.setInt(
      StorageKeys.maxMsSeen,
      current + (hours * 3600000).round(),
    );
  }

  group('OfflineProgressionService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(OfflineProgressionService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);
      expect(OfflineProgressionService.maybe, same(service));
    });

    test('chưa từng claim -> pendingEarnings = 0 (không tự ăn free)', () {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      expect(service.pendingEarnings(10), 0.0);
    });

    test('round-trip: đặt tốc độ, giả lập thời gian trôi, verify đúng số', () async {
      final service = OfflineProgressionService(
        maxOfflineCap: const Duration(hours: 8),
      );
      Get.put(service, permanent: true);

      // Baseline: claim ngay để chốt mốc "lần cuối claim" = bây giờ.
      final first = await service.claim(5);
      expect(first, 0.0);

      // Giả lập đi vắng 2 giờ, tốc độ 5/giây.
      await advanceHours(2);
      final earned = service.pendingEarnings(5);
      expect(earned, 2 * 3600 * 5);
    });

    test('vượt maxOfflineCap -> thu nhập bị giới hạn đúng cap, không tính vượt', () async {
      final service = OfflineProgressionService(
        maxOfflineCap: const Duration(hours: 8),
      );
      Get.put(service, permanent: true);

      await service.claim(2); // chốt mốc

      // Đi vắng 3 ngày (72 giờ) — vượt xa cap 8 giờ.
      await advanceHours(72);
      final earned = service.pendingEarnings(2);

      expect(earned, 8 * 3600 * 2, reason: 'chỉ tính tối đa 8 giờ, không tính 72 giờ thật');
    });

    test('pendingEarnings không mutate trạng thái (gọi nhiều lần ra cùng kết quả)', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      await service.claim(3);
      await advanceHours(1);

      final a = service.pendingEarnings(3);
      final b = service.pendingEarnings(3);
      expect(a, b);
    });

    test('claim() trả về đúng số đã tích luỹ VÀ reset mốc lastClaimed về hiện tại', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      await service.claim(4); // chốt mốc ban đầu
      await advanceHours(1);

      final earned = await service.claim(4);
      expect(earned, 1 * 3600 * 4);

      // Ngay sau khi claim, không còn gì để nhận nữa.
      expect(service.pendingEarnings(4), 0.0);
    });

    test('claim() persist mốc lastClaimed qua StorageKeys (sống sót qua restart)', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      await advanceHours(1);
      final before = nowMsClamped();
      await service.claim(1);

      // "Restart": tạo instance service mới, đọc lại từ storage.
      final restarted = OfflineProgressionService();
      expect(restarted.pendingEarnings(1), 0.0);
      expect(
        store.getInt(StorageKeys.offlineLastClaimedMs),
        greaterThanOrEqualTo(before),
      );
    });

    test('cap mặc định khi không truyền vào constructor', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      await service.claim(1);
      await advanceHours(1000); // rất xa, chắc chắn vượt bất kỳ cap mặc định nào

      final earned = service.pendingEarnings(1);
      expect(earned, service.maxOfflineCap.inSeconds * 1);
    });
  });
}
