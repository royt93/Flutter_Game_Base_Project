import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('ReminderService', () {
    // ENH-05: phải cùng base GetxService như StorageService/LocaleService/
    // AudioManager (permanent singleton, GetX không tự dispose) thay vì
    // GetxController (có thể bị dispose theo lifecycle route/binding).
    test('extends GetxService, không phải GetxController thường', () {
      expect(ReminderService(), isA<GetxService>());
    });

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
    test(
      'scheduleNext()/cancel() không throw khi platform channel vắng mặt',
      () async {
        final service = ReminderService();
        await expectLater(service.scheduleNext(), completes);
        await expectLater(service.cancel(), completes);
      },
    );
  });

  group('ReminderService (ENH-36: mock plugin platform channel)', () {
    // flutter_local_notifications' MethodChannelFlutterLocalNotificationsPlugin
    // gọi thẳng kênh này cho mọi thao tác (initialize/requestNotifications
    // Permission/zonedSchedule/cancel) — mock ở đây thay vì inject 1 fake
    // plugin, vì ReminderService không có seam DI cho _plugin và mock kênh
    // là cách đơn giản nhất không cần đổi production code.
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    var permissionGranted = true;

    // flutter_local_notifications registers this via a generated
    // `registerWith()` at real native plugin registration time, which
    // never runs in a plain `flutter_test` unit test — set it by hand so
    // `resolvePlatformSpecificImplementation<...>()` has a real instance to
    // resolve, matching what actually happens on a real device/app.
    setUpAll(() {
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    });

    void installHandler() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'initialize':
                return true;
              case 'requestNotificationsPermission':
                return permissionGranted;
              default:
                return null;
            }
          });
    }

    setUp(() {
      calls.clear();
      permissionGranted = true;
      installHandler();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'scheduleNext(): init trước, rồi zonedSchedule với đúng id/title/body',
      () async {
        final service = ReminderService();
        await service.scheduleNext(title: 'T', body: 'B');

        expect(calls.map((c) => c.method), [
          'initialize',
          'requestNotificationsPermission',
          'zonedSchedule',
        ]);
        final args = calls.last.arguments as Map;
        expect(args['id'], 0);
        expect(args['title'], 'T');
        expect(args['body'], 'B');
      },
    );

    test(
      'permission bị từ chối vẫn tiếp tục schedule (plugin không tự chặn ở '
      'tầng Dart khi requestNotificationsPermission trả về false)',
      () async {
        permissionGranted = false;
        final service = ReminderService();
        await service.scheduleNext();

        expect(calls.any((c) => c.method == 'zonedSchedule'), isTrue);
      },
    );

    test('cancel(): init trước, rồi gọi cancel với đúng id', () async {
      final service = ReminderService();
      await service.cancel();

      expect(calls.map((c) => c.method), [
        'initialize',
        'requestNotificationsPermission',
        'cancel',
      ]);
      final args = calls.last.arguments as Map;
      expect(args['id'], 0);
    });

    test(
      '2 lệnh gọi đồng thời (trước khi _ensureInit lần đầu hoàn tất) chỉ '
      'init đúng 1 lần',
      () async {
        final service = ReminderService();
        // KHÔNG await lần gọi đầu trước khi gọi lần 2 — cả 2 cùng đua vào
        // _ensureInit() khi _initialized vẫn còn false.
        final f1 = service.scheduleNext();
        final f2 = service.scheduleNext();
        await Future.wait([f1, f2]);

        final initCount = calls.where((c) => c.method == 'initialize').length;
        expect(initCount, 1);
      },
    );

    test('lỗi từ platform channel bị nuốt (dlog), không throw ra ngoài', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      final service = ReminderService();
      await expectLater(service.scheduleNext(), completes);
      await expectLater(service.cancel(), completes);
    });
  });
}
