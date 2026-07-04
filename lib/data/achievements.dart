import 'package:flutter/material.dart';

/// Loại chỉ số mà thành tựu theo dõi (đọc từ GameController).
enum AchStat {
  totalWins,
  totalStars,
  bestCombo,
  bestWinStreak,
  unlockedLevel,
  coinsEarned,
  clanContribTotal, // W23 — tổng đóng góp Clan tích luỹ
  platinumMilestones, // W25.3 — số mode phụ đã đạt mốc Platinum (tối đa 9)
}

/// Một thành tựu: đạt [threshold] của [stat] → mở khoá, nhận [reward] xu.
class Achievement {
  final String id;
  final IconData icon;
  final Color color;
  final AchStat stat;
  final int threshold;
  final int reward;

  const Achievement({
    required this.id,
    required this.icon,
    required this.color,
    required this.stat,
    required this.threshold,
    required this.reward,
  });

  /// Key i18n tiêu đề riêng từng thành tựu.
  String get titleKey => 'ach_${id}_t';

  /// Key i18n mô tả dùng chung theo [stat] (tham số @n = threshold).
  String get descKey => 'ach_desc_${stat.name}';
}

/// Danh sách thành tựu (offline). Màu lấy từ bảng neon.
const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_win',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFF39FF14),
    stat: AchStat.totalWins,
    threshold: 1,
    reward: 30,
  ),
  Achievement(
    id: 'wins_10',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF00FFFF),
    stat: AchStat.totalWins,
    threshold: 10,
    reward: 50,
  ),
  Achievement(
    id: 'wins_30',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFF6B00),
    stat: AchStat.totalWins,
    threshold: 30,
    reward: 100,
  ),
  Achievement(
    id: 'stars_30',
    icon: Icons.star_rounded,
    color: Color(0xFFFFFF00),
    stat: AchStat.totalStars,
    threshold: 30,
    reward: 60,
  ),
  Achievement(
    id: 'stars_90',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFFFFF00),
    stat: AchStat.totalStars,
    threshold: 90,
    reward: 150,
  ),
  Achievement(
    id: 'combo_5',
    icon: Icons.bolt_rounded,
    color: Color(0xFFFF00FF),
    stat: AchStat.bestCombo,
    threshold: 5,
    reward: 40,
  ),
  Achievement(
    id: 'combo_8',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFBC13FE),
    stat: AchStat.bestCombo,
    threshold: 8,
    reward: 80,
  ),
  Achievement(
    id: 'streak_3',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF6B00),
    stat: AchStat.bestWinStreak,
    threshold: 3,
    reward: 50,
  ),
  Achievement(
    id: 'streak_7',
    icon: Icons.whatshot_rounded,
    color: Color(0xFFFF00FF),
    stat: AchStat.bestWinStreak,
    threshold: 7,
    reward: 120,
  ),
  Achievement(
    id: 'world_2',
    icon: Icons.explore_rounded,
    color: Color(0xFF00FFFF),
    stat: AchStat.unlockedLevel,
    threshold: 21,
    reward: 60,
  ),
  Achievement(
    id: 'world_5',
    icon: Icons.public_rounded,
    color: Color(0xFFBC13FE),
    stat: AchStat.unlockedLevel,
    threshold: 81,
    reward: 200,
  ),
  Achievement(
    id: 'rich',
    icon: Icons.savings_rounded,
    color: Color(0xFFFFFF00),
    stat: AchStat.coinsEarned,
    threshold: 1000,
    reward: 100,
  ),
  // Wave 12 — tier CAO (giữ chân dài hạn). Desc dùng chung theo stat → chỉ cần
  // thêm key TITLE i18n (ach_<id>_t).
  Achievement(
    id: 'wins_60',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF00FFFF),
    stat: AchStat.totalWins,
    threshold: 60,
    reward: 200,
  ),
  Achievement(
    id: 'wins_100',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFD700),
    stat: AchStat.totalWins,
    threshold: 100,
    reward: 350,
  ),
  Achievement(
    id: 'stars_180',
    icon: Icons.star_rounded,
    color: Color(0xFFFFFF00),
    stat: AchStat.totalStars,
    threshold: 180,
    reward: 250,
  ),
  Achievement(
    id: 'stars_300',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFFFD700),
    stat: AchStat.totalStars,
    threshold: 300,
    reward: 500,
  ),
  Achievement(
    id: 'combo_12',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFBC13FE),
    stat: AchStat.bestCombo,
    threshold: 12,
    reward: 150,
  ),
  Achievement(
    id: 'streak_12',
    icon: Icons.whatshot_rounded,
    color: Color(0xFFFF00FF),
    stat: AchStat.bestWinStreak,
    threshold: 12,
    reward: 200,
  ),
  Achievement(
    id: 'rich_5000',
    icon: Icons.diamond_rounded,
    color: Color(0xFFFFD700),
    stat: AchStat.coinsEarned,
    threshold: 5000,
    reward: 300,
  ),
  // W23 — Clan: đóng góp tích luỹ
  Achievement(
    id: 'clan_contrib1',
    icon: Icons.groups_rounded,
    color: Color(0xFF1DE9B6),
    stat: AchStat.clanContribTotal,
    threshold: 100,
    reward: 60,
  ),
  Achievement(
    id: 'clan_contrib2',
    icon: Icons.shield_rounded,
    color: Color(0xFF536DFE),
    stat: AchStat.clanContribTotal,
    threshold: 500,
    reward: 150,
  ),
  // W25.3 — Platinum side-mode: danh hiệu đeo được qua equipTitle() có sẵn.
  Achievement(
    id: 'platinum_1',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFE0E0E0),
    stat: AchStat.platinumMilestones,
    threshold: 1,
    reward: 100,
  ),
  Achievement(
    id: 'platinum_4',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFB9F2FF),
    stat: AchStat.platinumMilestones,
    threshold: 4,
    reward: 300,
  ),
  Achievement(
    id: 'platinum_9',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFF2BD6),
    stat: AchStat.platinumMilestones,
    threshold: 9,
    reward: 700,
  ),
];
