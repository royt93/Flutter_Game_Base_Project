import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../../data/mascot_skins.dart';
import 'star_mascot.dart';

/// I87: thẻ "hành trình của bạn" để chia sẻ từ `MilestoneJournalScreen`.
///
/// Cùng khuôn với `ScoreCard` (I57): bố cục **cố định**, mọi dữ liệu vào qua
/// constructor, không chạm `GameController` — nhờ vậy test được độc lập và
/// chụp được bằng đúng `captureBoardPng` sẵn có, không dựng pipeline xuất ảnh
/// thứ hai.
///
/// Tỉ lệ **1:1** (`_side`): chốt một tỉ lệ thay vì làm cả vuông lẫn dọc. Vuông
/// là tỉ lệ hiếm khi bị cắt xén ở bất kỳ nền tảng nào.
class JourneyCard extends StatelessWidget {
  const JourneyCard({
    super.key,
    required this.playerName,
    required this.totalStars,
    required this.highestLevel,
    required this.maxCombo,
    required this.daysPlayed,
    required this.milestoneLines,
    required this.mascotPalette,
  });

  /// Tên người chơi tự nhập. Rỗng → dùng nhãn chung; tuyệt đối không để trống
  /// hay hiện "null" trên ảnh sẽ đi ra ngoài app.
  final String playerName;

  final int totalStars;
  final int highestLevel;
  final int maxCombo;
  final int daysPlayed;

  /// Các dòng mốc **đã dịch sẵn** — widget cố ý không biết `MilestoneKind`.
  /// Việc chọn mốc là hàm thuần `pickJourneyMilestones`; việc dịch là của màn
  /// hình, nơi đã có sẵn `_titleFor`.
  final List<String> milestoneLines;

  final MascotPalette mascotPalette;

  static const double _side = 360;

  @override
  Widget build(BuildContext context) {
    final name = playerName.trim().isEmpty
        ? 'journey_card_anonymous'.tr
        : playerName.trim();

    return Container(
      width: _side,
      height: _side,
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NeonTheme.card, NeonTheme.cardAlt],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: mascotPalette.glow, width: 4),
        boxShadow: NeonTheme.glow(mascotPalette.glow, blur: 26, spread: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StarMascot(size: 52, palette: mascotPalette),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'journey_card_title'.tr,
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                icon: Icons.star_rounded,
                color: NeonTheme.gold,
                value: '$totalStars',
                labelKey: 'journey_card_stars',
              ),
              _Stat(
                icon: Icons.flag_rounded,
                color: NeonTheme.teal,
                value: '$highestLevel',
                labelKey: 'journey_card_level',
              ),
              _Stat(
                icon: Icons.local_fire_department_rounded,
                color: NeonTheme.orange,
                value: '$maxCombo',
                labelKey: 'journey_card_combo',
              ),
              _Stat(
                icon: Icons.calendar_month_rounded,
                color: NeonTheme.purple,
                value: '$daysPlayed',
                labelKey: 'journey_card_days',
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          // Danh sách mốc co lại vừa chỗ còn thừa: thẻ là ảnh vuông cố định,
          // tràn ở đây sẽ đi thẳng ra ảnh chia sẻ chứ không chỉ là cảnh báo
          // trong debug.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in milestoneLines)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: mascotPalette.glow,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Tên riêng, giống nhau ở mọi ngôn ngữ -> hằng số, không phải key
          // dịch. Khác hẳn ca [[X31]] (chữ "xu" bị hard-code tiếng Việt).
          Text(
            kAppName,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.labelKey,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        Text(
          value,
          style: TextStyle(
            color: NeonTheme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          labelKey.tr,
          style: TextStyle(color: NeonTheme.inkSoft, fontSize: 10),
        ),
      ],
    );
  }
}
