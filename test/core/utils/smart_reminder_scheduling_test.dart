import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/daily_login_service.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/smart_reminder_scheduling.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pins `nowMsClamped()`/`todayEpochDayClamped()` to a synthetic instant
/// by writing directly to the watermark keys they clamp against — same
/// technique other services' own tests use to control "now" without real
/// wall-clock timing.
Future<void> _pinNow(StorageService store, int nowMs) async {
  await store.setInt(StorageKeys.maxMsSeen, nowMs);
  await store.setInt(StorageKeys.maxEpochDaySeen, nowMs ~/ 86400000);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('energyFullReminderDelay (pure)', () {
    test('đã đầy năng lượng -> null (không cần nhắc)', () {
      final energy = EnergyService(maxEnergy: 5, refillInterval: const Duration(minutes: 30));
      Get.put(energy, permanent: true);

      expect(energyFullReminderDelay(energy), isNull);
    });

    test('đang có infinite lives -> null (không cần nhắc)', () async {
      final energy = EnergyService(maxEnergy: 5, refillInterval: const Duration(minutes: 30));
      Get.put(energy, permanent: true);
      await energy.grantInfiniteLives(const Duration(hours: 1));

      expect(energyFullReminderDelay(energy), isNull);
    });

    test(
      'thiếu N điểm -> delay = timeUntilNextEnergy + (N-1) * refillInterval',
      () {
        const interval = Duration(minutes: 30);
        final energy = EnergyService(maxEnergy: 5, refillInterval: interval);
        Get.put(energy, permanent: true);
        energy.consumeEnergy(3); // còn 2, thiếu 3

        final delay = energyFullReminderDelay(energy)!;
        final expected = energy.timeUntilNextEnergy + interval * 2;

        expect(delay, expected);
      },
    );
  });

  group('streakExpiringReminderDelay (pure)', () {
    test(
      'còn xa hạn chót -> delay = (thời gian tới nửa đêm UTC) - warnBefore',
      () async {
        final dailyLogin = DailyLoginService();
        Get.put(dailyLogin, permanent: true);

        // Pin "now" tại đúng đầu 1 ngày UTC (epoch day * 86400000).
        const epochDay = 999999;
        await _pinNow(store, epochDay * 86400000);

        final delay = streakExpiringReminderDelay(
          dailyLogin,
          warnBefore: const Duration(hours: 4),
        );

        expect(delay, const Duration(hours: 20)); // 24h - 4h
      },
    );

    test(
      'đã trong khoảng warnBefore trước hạn chót -> delay = zero (nhắc ngay)',
      () async {
        final dailyLogin = DailyLoginService();
        Get.put(dailyLogin, permanent: true);

        const epochDay = 999999;
        // Pin "now" chỉ còn 1 giờ tới nửa đêm UTC (23h vào ngày).
        await _pinNow(store, epochDay * 86400000 + const Duration(hours: 23).inMilliseconds);

        final delay = streakExpiringReminderDelay(
          dailyLogin,
          warnBefore: const Duration(hours: 4),
        );

        expect(delay, Duration.zero);
      },
    );

    test('warnBefore tuỳ chỉnh được áp dụng đúng', () async {
      final dailyLogin = DailyLoginService();
      Get.put(dailyLogin, permanent: true);

      const epochDay = 999999;
      await _pinNow(store, epochDay * 86400000);

      final delay = streakExpiringReminderDelay(
        dailyLogin,
        warnBefore: const Duration(hours: 1),
      );

      expect(delay, const Duration(hours: 23));
    });
  });

  group(
    'rescheduleEnergyReminder / rescheduleStreakReminder (mock reminder plugin channel)',
    () {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];

      setUpAll(() {
        FlutterLocalNotificationsPlatform.instance =
            AndroidFlutterLocalNotificationsPlugin();
      });

      setUp(() {
        calls.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              switch (call.method) {
                case 'initialize':
                  return true;
                case 'requestNotificationsPermission':
                  return true;
                default:
                  return null;
              }
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      test(
        'còn thiếu năng lượng -> scheduleNext đúng id + delay tính được',
        () async {
          const interval = Duration(minutes: 30);
          final energy = EnergyService(maxEnergy: 5, refillInterval: interval);
          Get.put(energy, permanent: true);
          energy.consumeEnergy(3);
          final reminder = ReminderService();

          await rescheduleEnergyReminder(energy: energy, reminder: reminder);

          final scheduleCall = calls.firstWhere((c) => c.method == 'zonedSchedule');
          expect(
            (scheduleCall.arguments as Map)['id'],
            kEnergyReminderNotificationId,
          );
          expect(calls.any((c) => c.method == 'cancel'), isFalse);
        },
      );

      test('đã đầy năng lượng -> cancel đúng id, KHÔNG schedule mới', () async {
        final energy = EnergyService(maxEnergy: 5);
        Get.put(energy, permanent: true);
        final reminder = ReminderService();

        await rescheduleEnergyReminder(energy: energy, reminder: reminder);

        final cancelCall = calls.firstWhere((c) => c.method == 'cancel');
        expect(
          (cancelCall.arguments as Map)['id'],
          kEnergyReminderNotificationId,
        );
        expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
      });

      test(
        'chưa claim hôm nay -> scheduleNext đúng id cho streak reminder',
        () async {
          final dailyLogin = DailyLoginService();
          Get.put(dailyLogin, permanent: true);
          final reminder = ReminderService();

          await rescheduleStreakReminder(
            dailyLogin: dailyLogin,
            reminder: reminder,
          );

          final scheduleCall = calls.firstWhere((c) => c.method == 'zonedSchedule');
          expect(
            (scheduleCall.arguments as Map)['id'],
            kStreakReminderNotificationId,
          );
        },
      );

      test(
        'đã claim hôm nay -> cancel đúng id, KHÔNG schedule mới (AC3: '
        'streak được claim trước giờ nhắc phải huỷ lịch cũ)',
        () async {
          final dailyLogin = DailyLoginService();
          Get.put(dailyLogin, permanent: true);
          dailyLogin.claimToday();
          final reminder = ReminderService();

          await rescheduleStreakReminder(
            dailyLogin: dailyLogin,
            reminder: reminder,
          );

          final cancelCall = calls.firstWhere((c) => c.method == 'cancel');
          expect(
            (cancelCall.arguments as Map)['id'],
            kStreakReminderNotificationId,
          );
          expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
        },
      );

      test(
        'gọi lại rescheduleEnergyReminder sau khi tiêu hết -> lịch cũ (full) '
        'bị huỷ, lịch mới (thiếu năng lượng) được đặt — không lệch',
        () async {
          final energy = EnergyService(maxEnergy: 5);
          Get.put(energy, permanent: true);
          final reminder = ReminderService();

          // Lần 1: đầy -> cancel.
          await rescheduleEnergyReminder(energy: energy, reminder: reminder);
          expect(calls.any((c) => c.method == 'cancel'), isTrue);
          expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);

          calls.clear();
          energy.consumeEnergy(1);

          // Lần 2: thiếu -> schedule mới, không còn cancel-only nữa.
          await rescheduleEnergyReminder(energy: energy, reminder: reminder);
          expect(calls.any((c) => c.method == 'zonedSchedule'), isTrue);
        },
      );
    },
  );
}
