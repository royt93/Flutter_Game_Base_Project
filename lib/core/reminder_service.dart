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

  // ENH-36: memoizes the in-flight init Future so 2 concurrent callers (e.g.
  // scheduleNext() and cancel() both racing in before either has finished)
  // await the SAME init instead of each independently re-running
  // FlutterLocalNotificationsPlugin.initialize() — previously nothing
  // guarded against `_initialized` still being false for both callers.
  Future<void>? _initFuture;

  Future<void> _ensureInit() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    tzdata.initializeTimeZones();
    // ENH-36: without this, `tz.local` (a `late` field the `timezone`
    // package never sets on its own) throws LateInitializationError on
    // every single scheduleNext()/cancel() call — silently swallowed by
    // their try/catch as a "failed" dlog, so reminders never actually
    // fired on a real device despite no test ever catching it. UTC (not
    // the device's real zone) is fine here: this service only ever
    // schedules a relative delay from "now", never an absolute local
    // wall-clock time, so the zone used for that arithmetic doesn't
    // change the resulting absolute moment.
    tz.setLocalLocation(tz.UTC);
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
