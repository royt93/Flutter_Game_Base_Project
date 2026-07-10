import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/season.dart';
import '../controllers/game_controller.dart';
import '../controllers/season_league_controller.dart';

String _fmtCountdown(Duration d) {
  final days = d.inDays;
  final h = d.inHours.remainder(24).toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return days > 0 ? '${days}d $h:$m:$s' : '$h:$m:$s';
}

/// W28.5 — Banner sự kiện tuần trên World Map. Luôn hiển thị (kể cả tuần
/// "Không Đặc Biệt", coinMult 1.0) để nhất quán mỗi tuần đều có tín hiệu.
/// Countdown tái dùng NGUYÊN [SeasonLeagueController.timeToEnd] — cùng ranh
/// giới tuần với Season League, không tính lại epoch-week riêng.
class WeeklyEventBanner extends StatelessWidget {
  const WeeklyEventBanner(this.controller, {super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final event = currentWeeklyEvent(controller.todayEpochDay);
    final lc = SeasonLeagueController.maybe;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeonTheme.magenta, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.magenta, blur: 6),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: NeonTheme.magenta, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.nameKey.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  event.descKey.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (lc != null)
            Text(
              _fmtCountdown(lc.timeToEnd),
              style: const TextStyle(
                color: NeonTheme.magenta,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
