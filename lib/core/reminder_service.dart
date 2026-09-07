import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'debug_log.dart';

/// One local notification, scheduled a fixed delay out. Games that need
/// several reminder kinds/priorities should extend this, not add branches
/// here — keep the base's default path to exactly one notification.
class ReminderService extends GetxService {
  static ReminderService? get maybe =>
      Get.isRegistered<ReminderService>() ? Get.find<ReminderService>() : null;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );
    // Android 13+ requires this granted at runtime or scheduling silently
    // never fires; iOS handles its own permission prompt via
    // DarwinInitializationSettings defaults.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> scheduleNext({
    Duration delay = const Duration(hours: 24),
    String title = 'Roy Project Base Game',
    String body = 'Come back and play!',
  }) async {
    try {
      await _ensureInit();
      await _plugin.zonedSchedule(
        id: 0,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('reminders', 'Reminders'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      dlog('ReminderService.scheduleNext failed: $e');
    }
  }

  Future<void> cancel() async {
    try {
      await _ensureInit();
      await _plugin.cancel(id: 0);
    } catch (e) {
      dlog('ReminderService.cancel failed: $e');
    }
  }
}
