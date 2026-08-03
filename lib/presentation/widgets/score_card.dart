import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/mascot_skins.dart';
import 'star_mascot.dart';

/// I57: thẻ kết quả tổng hợp (điểm + tổng sao + rank offline nếu có + mascot
/// đang mặc) để chia sẻ ra ngoài app — tách biệt ảnh chụp board của F15.
/// Bố cục cố định, nhận dữ liệu qua constructor để test độc lập với
/// `GameController`/plugin share (xem `shareScoreCard` trong `share_helper.dart`).
class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.score,
    required this.totalStars,
    required this.mascotPalette,
    this.rank,
  });

  final int score;
  final int totalStars;
  final MascotPalette mascotPalette;

  /// Hạng 1-indexed trong leaderboard offline của mode hiện tại — null nếu
  /// mode không có leaderboard (vd. campaign), khi đó ẩn hẳn dòng rank thay
  /// vì hiện "N/A".
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(NeonTheme.s24),
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
          StarMascot(size: 96, palette: mascotPalette),
          const SizedBox(height: NeonTheme.s16),
          Text(
            'score_value_label'.trParams({'score': '$score'}),
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: NeonTheme.gold, size: 22),
              const SizedBox(width: 4),
              Text(
                '$totalStars',
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (rank != null) ...[
            const SizedBox(height: NeonTheme.s8),
            Text(
              'score_card_rank_label'.trParams({'rank': '$rank'}),
              style: const TextStyle(
                color: NeonTheme.teal,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
