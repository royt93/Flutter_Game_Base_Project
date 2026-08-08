import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/weekly_goal.dart';
import '../presentation/controllers/game_controller.dart';
import 'debug_log.dart';
import 'storage_service.dart';

/// I56/I78: 4 loại nhắc local (không backend), ưu tiên theo thứ tự cố định —
/// [pickReminderKind] chỉ chọn 1 loại/lần.
enum ReminderKind { spin, streak, weeklyGoal, questBoard }

/// Thời gian còn lại tới UTC midnight kế tiếp — cùng boundary với
/// `todayEpochDay()` (`game_controller.dart` dòng ~898-906).
Duration timeUntilNextDailyReset({required int nowEpochMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(nowEpochMs, isUtc: true);
  final today = DateTime.utc(now.year, now.month, now.day);
  return today.add(const Duration(days: 1)).difference(now);
}

/// Thời gian còn lại tới lúc `weekIndexForEpochDay()` (`weekly_goal.dart`)
/// đổi giá trị kế tiếp.
Duration timeUntilNextWeeklyReset({required int nowEpochMs}) {
  final epochDay = nowEpochMs ~/ 86400000;
  final nextWeekStartDay = (weekIndexForEpochDay(epochDay) + 1) * 7;
  return Duration(milliseconds: nextWeekStartDay * 86400000 - nowEpochMs);
}

/// Chọn loại nhắc theo thứ tự ưu tiên cố định: (1) còn spin hôm nay chưa
/// quay, (2) chưa nhận thưởng streak hôm nay, (3) weekly goal chưa xong và
/// tuần sắp hết (≤1 ngày), (4) có Daily Quest đã đủ điều kiện nhận nhưng
/// chưa nhận (I78 — thấp nhất, chỉ nhắc khi 3 loại trên không áp dụng). Pure
/// — test độc lập với plugin thật.
ReminderKind? pickReminderKind({
  required bool canClaimSpin,
  required bool streakRewardUnclaimed,
  required bool weeklyGoalIncomplete,
  required Duration weeklyRemaining,
  required bool questBoardClaimable,
}) {
  if (canClaimSpin) return ReminderKind.spin;
  if (streakRewardUnclaimed) return ReminderKind.streak;
  if (weeklyGoalIncomplete && weeklyRemaining <= const Duration(days: 1)) {
    return ReminderKind.weeklyGoal;
  }
  if (questBoardClaimable) return ReminderKind.questBoard;
  return null;
}

class _ReminderContent {
  final String title;
  final String body;
  const _ReminderContent(this.title, this.body);
}

/// I56 — Local Smart Reminder: nhắc người chơi khi streak/spin/weekly-goal
/// sắp hết hạn. Không backend — lên lịch lại 1 notification duy nhất mỗi
/// lần app mở (`main.dart`/`HomeScreenController`), huỷ lịch cũ trước khi
/// đặt lịch mới để tránh tích luỹ trùng.
class ReminderService extends GetxService {
  static const int _notificationId = 5600;
  // "Gần hết ngày/tuần" — bắn trước mốc reset 3 giờ thay vì đúng lúc reset.
  static const Duration _leadTime = Duration(hours: 3);
  static const Duration _minDelay = Duration(minutes: 1);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _pluginInitialized = false;

  static ReminderService? get maybe =>
      Get.isRegistered<ReminderService>() ? Get.find<ReminderService>() : null;

  bool get enabled =>
      StorageService.to.getBool(StorageKeys.remindersEnabled, def: true);

  Future<void> _ensurePluginInitialized() async {
    if (_pluginInitialized) return;
    tzdata.initializeTimeZones();
    // Chỉ dùng để cộng Duration tương đối vào "now" — không cần đúng
    // timezone thiết bị, ponytail: giữ UTC cho đơn giản + nhất quán với
    // `todayEpochDay()` (cũng tính theo UTC).
    tz.setLocalLocation(tz.UTC);
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );
    _pluginInitialized = true;
  }

  /// Xin quyền hiển thị notification runtime (Android 13+ / iOS). Từ chối →
  /// trả false, KHÔNG throw/crash — gọi nơi khác tự tắt tính năng âm thầm.
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  Future<void> setEnabled(bool value) async {
    StorageService.to.setBool(StorageKeys.remindersEnabled, value);
    if (value) {
      await scheduleNext();
    } else {
      await _plugin.cancelAll();
    }
  }

  /// Huỷ lịch cũ rồi đặt lại đúng 1 notification (nếu có điều kiện phù hợp).
  /// An toàn gọi nhiều lần — mọi lỗi (permission/plugin) bị nuốt, chỉ log.
  Future<void> scheduleNext() async {
    try {
      await _ensurePluginInitialized();
      await _plugin.cancelAll();
      if (!enabled) return;
      if (!Get.isRegistered<GameController>()) return;
      if (!await _requestPermission()) return;

      final gameCtrl = Get.find<GameController>();
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final dailyRemaining = timeUntilNextDailyReset(nowEpochMs: nowMs);
      final weeklyRemaining = timeUntilNextWeeklyReset(nowEpochMs: nowMs);
      final kind = pickReminderKind(
        canClaimSpin: gameCtrl.canClaimSpin,
        streakRewardUnclaimed: _streakRewardUnclaimedToday(gameCtrl),
        weeklyGoalIncomplete:
            gameCtrl.weeklyGoalProgress.value < weeklyGoalTarget,
        weeklyRemaining: weeklyRemaining,
        questBoardClaimable: _questBoardClaimable(gameCtrl),
      );
      if (kind == null) return;

      final delay = _clampedDelay(
        kind == ReminderKind.weeklyGoal ? weeklyRemaining : dailyRemaining,
      );
      final content = _contentFor(kind);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: content.title,
        body: content.body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      dlog('roy93~ ReminderService.scheduleNext lỗi (bỏ qua): $e');
    }
  }

  Duration _clampedDelay(Duration untilReset) {
    final withLead = untilReset - _leadTime;
    return withLead > _minDelay ? withLead : _minDelay;
  }

  bool _streakRewardUnclaimedToday(GameController gameCtrl) {
    final day = gameCtrl.dayInCycle(gameCtrl.loginStreakCount.value);
    final reward = GameController.loginStreakRewards[day];
    if (reward == null) return false;
    return (gameCtrl.loginStreakClaimedMask.value >> day) & 1 == 0;
  }

  /// I78 — có ≥1 Daily Quest hôm nay đã đủ điều kiện nhận thưởng nhưng chưa
  /// nhận. Gọi `checkDailyQuestRollover()` trước để đảm bảo `dailyQuests`/
  /// tiến độ đã khớp ngày hiện tại (mirror cách `claimDailyQuest` tự vệ).
  bool _questBoardClaimable(GameController gameCtrl) {
    gameCtrl.checkDailyQuestRollover();
    final quests = gameCtrl.dailyQuests;
    final progress = gameCtrl.dailyQuestProgress;
    for (var i = 0; i < quests.length; i++) {
      if (gameCtrl.dailyQuestClaimed.contains(i)) continue;
      if (progress[i] >= quests[i].target) return true;
    }
    return false;
  }

  _ReminderContent _contentFor(ReminderKind kind) {
    switch (kind) {
      case ReminderKind.spin:
        return _ReminderContent(
          'reminder_spin_title'.tr,
          'reminder_spin_body'.tr,
        );
      case ReminderKind.streak:
        return _ReminderContent(
          'reminder_streak_title'.tr,
          'reminder_streak_body'.tr,
        );
      case ReminderKind.weeklyGoal:
        return _ReminderContent(
          'reminder_weekly_goal_title'.tr,
          'reminder_weekly_goal_body'.tr,
        );
      case ReminderKind.questBoard:
        return _ReminderContent(
          'reminder_quest_board_title'.tr,
          'reminder_quest_board_body'.tr,
        );
    }
  }

  @override
  void onClose() {
    // restartApp() xoá hết singleton khi restore backup — huỷ lịch cũ để
    // tránh notification treo sau khi data đã bị xoá/ghi đè.
    _plugin.cancelAll();
    super.onClose();
  }
}
