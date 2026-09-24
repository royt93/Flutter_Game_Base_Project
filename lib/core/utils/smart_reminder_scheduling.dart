import '../daily_login_service.dart';
import '../energy_service.dart';
import '../reminder_service.dart';
import 'clamped_clock.dart';

/// [ReminderService.scheduleNext]/[ReminderService.cancel] `id` for the
/// energy-full reminder scheduled by [rescheduleEnergyReminder] — distinct
/// from [ReminderService]'s own default `id: 0` slot and from
/// [kStreakReminderNotificationId], so all 3 coexist as independent
/// notifications.
const int kEnergyReminderNotificationId = 1;

/// [ReminderService.scheduleNext]/[ReminderService.cancel] `id` for the
/// streak-expiring reminder scheduled by [rescheduleStreakReminder].
const int kStreakReminderNotificationId = 2;

/// How long until [energy]'s bar is completely full (`null` if it already
/// is, or [EnergyService.hasInfiniteLives] is active — no reminder is
/// useful in either case). Pure function of [energy]'s own already-tested
/// getters ([EnergyService.currentEnergy]/[EnergyService.timeUntilNextEnergy]),
/// not a new regen formula — [EnergyService.timeUntilNextEnergy] alone
/// only answers "until the NEXT point", so this adds the remaining whole
/// ticks after that on top.
Duration? energyFullReminderDelay(EnergyService energy) {
  if (energy.hasInfiniteLives) return null;
  final current = energy.currentEnergy;
  final pointsNeeded = energy.maxEnergy - current;
  if (pointsNeeded <= 0) return null;
  final wholeTicksAfterNext = pointsNeeded - 1;
  return energy.timeUntilNextEnergy +
      energy.refillInterval * wholeTicksAfterNext;
}

/// How long until a reminder should fire warning the player their
/// [dailyLogin] streak is about to lapse — `null` if today's reward is
/// already claimed (the streak is safe, no reminder needed).
///
/// The streak actually expires at the next UTC day boundary (the same
/// `todayEpochDayClamped()` [dailyLogin] itself is built on — see
/// `utils/clamped_clock.dart`), not local midnight. The returned delay
/// fires [warnBefore] ahead of that boundary — clamped to `Duration.zero`
/// (fire immediately) if the boundary is already closer than [warnBefore]
/// by the time this is called (e.g. the app was closed the whole day and
/// only reopened a few minutes before it lapses).
Duration streakExpiringReminderDelay(
  DailyLoginService dailyLogin, {
  Duration warnBefore = const Duration(hours: 4),
}) {
  final nowMs = nowMsClamped();
  final today = todayEpochDayClamped();
  final nextBoundaryMs = (today + 1) * 86400000;
  final msUntilBoundary = nextBoundaryMs - nowMs;
  final delayMs = msUntilBoundary - warnBefore.inMilliseconds;
  return Duration(milliseconds: delayMs < 0 ? 0 : delayMs);
}

/// Re-derives the energy-full reminder from [energy]'s CURRENT state and
/// (re)schedules it via [reminder] at [kEnergyReminderNotificationId] —
/// or cancels that slot if no reminder is currently useful (already full,
/// or infinite lives active). Call this again any time energy state
/// changes (after `consumeEnergy`, after `grantInfiniteLives`, on app
/// resume) so a stale schedule never outlives the state it was computed
/// from (IDEA-62's AC3) — this coordinator has no way to observe those
/// changes on its own, by design (no new cross-service event bus for
/// something a caller can just call directly at the right hooks).
Future<void> rescheduleEnergyReminder({
  required EnergyService energy,
  required ReminderService reminder,
  String title = 'Năng lượng đã đầy!',
  String body = 'Quay lại chơi ngay để không lãng phí năng lượng.',
}) async {
  final delay = energyFullReminderDelay(energy);
  if (delay == null) {
    await reminder.cancel(id: kEnergyReminderNotificationId);
    return;
  }
  await reminder.scheduleNext(
    id: kEnergyReminderNotificationId,
    delay: delay,
    title: title,
    body: body,
  );
}

/// Re-derives the streak-expiring reminder from [dailyLogin]'s CURRENT
/// state and (re)schedules it via [reminder] at
/// [kStreakReminderNotificationId] — or cancels that slot if today's
/// reward is already claimed. Call this again any time login-streak state
/// changes (after `claimToday`, on app resume) for the same reason
/// [rescheduleEnergyReminder]'s own doc explains.
Future<void> rescheduleStreakReminder({
  required DailyLoginService dailyLogin,
  required ReminderService reminder,
  Duration warnBefore = const Duration(hours: 4),
  String title = 'Đừng để mất streak!',
  String body = 'Streak điểm danh của bạn sắp hết hạn hôm nay.',
}) async {
  if (!dailyLogin.canClaimToday()) {
    await reminder.cancel(id: kStreakReminderNotificationId);
    return;
  }
  final delay = streakExpiringReminderDelay(dailyLogin, warnBefore: warnBefore);
  await reminder.scheduleNext(
    id: kStreakReminderNotificationId,
    delay: delay,
    title: title,
    body: body,
  );
}
