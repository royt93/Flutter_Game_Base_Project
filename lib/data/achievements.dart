import 'package:flutter/material.dart';

/// Loại chỉ số mà thành tựu theo dõi (đọc từ GameController).
enum AchStat {
  totalWins,
  totalStars,
  bestCombo,
  bestWinStreak,
  unlockedLevel,
  coinsEarned,
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
      reward: 30),
  Achievement(
      id: 'wins_10',
      icon: Icons.military_tech_rounded,
      color: Color(0xFF00FFFF),
      stat: AchStat.totalWins,
      threshold: 10,
      reward: 50),
  Achievement(
      id: 'wins_30',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFF6B00),
      stat: AchStat.totalWins,
      threshold: 30,
      reward: 100),
  Achievement(
      id: 'stars_30',
      icon: Icons.star_rounded,
      color: Color(0xFFFFFF00),
      stat: AchStat.totalStars,
      threshold: 30,
      reward: 60),
  Achievement(
      id: 'stars_90',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFFF00),
      stat: AchStat.totalStars,
      threshold: 90,
      reward: 150),
  Achievement(
      id: 'combo_5',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFF00FF),
      stat: AchStat.bestCombo,
      threshold: 5,
      reward: 40),
  Achievement(
      id: 'combo_8',
      icon: Icons.flash_on_rounded,
      color: Color(0xFFBC13FE),
      stat: AchStat.bestCombo,
      threshold: 8,
      reward: 80),
  Achievement(
      id: 'streak_3',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF6B00),
      stat: AchStat.bestWinStreak,
      threshold: 3,
      reward: 50),
  Achievement(
      id: 'streak_7',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFFF00FF),
      stat: AchStat.bestWinStreak,
      threshold: 7,
      reward: 120),
  Achievement(
      id: 'world_2',
      icon: Icons.explore_rounded,
      color: Color(0xFF00FFFF),
      stat: AchStat.unlockedLevel,
      threshold: 21,
      reward: 60),
  Achievement(
      id: 'world_5',
      icon: Icons.public_rounded,
      color: Color(0xFFBC13FE),
      stat: AchStat.unlockedLevel,
      threshold: 81,
      reward: 200),
  Achievement(
      id: 'rich',
      icon: Icons.savings_rounded,
      color: Color(0xFFFFFF00),
      stat: AchStat.coinsEarned,
      threshold: 1000,
      reward: 100),
];
