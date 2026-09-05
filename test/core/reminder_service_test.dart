import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('ReminderService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(ReminderService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = ReminderService();
      Get.put(service, permanent: true);
      expect(ReminderService.maybe, same(service));
    });

    // scheduleNext()/cancel() gọi flutter_local_notifications qua platform
    // channel — không có mock kênh này trong unit test, nhưng cả hai đều
    // try/catch nội bộ và chỉ dlog khi lỗi (xem reminder_service.dart), nên
    // ta chỉ xác nhận chúng hoàn tất mà không throw ra ngoài.
    test('scheduleNext()/cancel() không throw khi platform channel vắng mặt', () async {
      final service = ReminderService();
      await expectLater(service.scheduleNext(), completes);
      await expectLater(service.cancel(), completes);
    });
  });
}
