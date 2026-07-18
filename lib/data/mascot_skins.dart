import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

/// I30: bảng màu cho `_StarPainter` — chỉ đổi quầng sáng/gradient thân/viền,
/// giữ nguyên hình dạng sao + mặt (mắt/má/miệng) theo mọi skin.
class MascotPalette {
  const MascotPalette({
    required this.glow,
    required this.gradientStart,
    required this.gradientEnd,
    required this.outline,
  });

  final Color glow;
  final Color gradientStart;
  final Color gradientEnd;
  final Color outline;

  @override
  bool operator ==(Object other) =>
      other is MascotPalette &&
      other.glow == glow &&
      other.gradientStart == gradientStart &&
      other.gradientEnd == gradientEnd &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(glow, gradientStart, gradientEnd, outline);
}

/// I30: 1 trang phục (skin) cho mascot ngôi sao. Mở khoá bằng ĐÚNG MỘT trong 2
/// cách — mua xu ([coinPrice]) hoặc đạt thành tựu mốc cao ([unlockAchievementId]) —
/// không bao giờ cả hai cùng lúc.
class MascotSkin {
  const MascotSkin({
    required this.id,
    required this.nameKey,
    required this.palette,
    this.coinPrice,
    this.unlockAchievementId,
  }) : assert(
         (coinPrice == null) != (unlockAchievementId == null) ||
             (coinPrice == null && unlockAchievementId == null),
         'coinPrice và unlockAchievementId không được cùng khác null',
       );

  final String id;
  final String nameKey;
  final MascotPalette palette;
  final int? coinPrice;
  final String? unlockAchievementId;

  /// Skin mặc định — luôn mở khoá sẵn, không tốn xu, không cần achievement.
  bool get isFree => coinPrice == null && unlockAchievementId == null;
}

/// Public vì `StarMascot` (`presentation/widgets/star_mascot.dart`) dùng làm
/// giá trị mặc định cho param `palette` — 1 nguồn duy nhất, tránh trùng định
/// nghĩa palette "classic" ở 2 nơi.
const classicMascotPalette = MascotPalette(
  glow: NeonTheme.gold,
  gradientStart: Color(0xFFFFE27A),
  gradientEnd: NeonTheme.gold,
  outline: Color(0xFFE59A1E),
);

const _rubyPalette = MascotPalette(
  glow: Color(0xFFFF4D6D),
  gradientStart: Color(0xFFFF8FA3),
  gradientEnd: Color(0xFFE0223F),
  outline: Color(0xFFB3102A),
);

const _emeraldPalette = MascotPalette(
  glow: Color(0xFF2ECC71),
  gradientStart: Color(0xFF8CF5B0),
  gradientEnd: Color(0xFF1E9E56),
  outline: Color(0xFF126B39),
);

const _sapphirePalette = MascotPalette(
  glow: Color(0xFF3B82F6),
  gradientStart: Color(0xFF9AC5FF),
  gradientEnd: Color(0xFF1D4FD1),
  outline: Color(0xFF12308A),
);

const _auroraPalette = MascotPalette(
  glow: Color(0xFFB36BFF),
  gradientStart: Color(0xFFFFD86B),
  gradientEnd: Color(0xFF8A2BE2),
  outline: Color(0xFF5B1899),
);

const _obsidianPalette = MascotPalette(
  glow: Color(0xFF6C7BFF),
  gradientStart: Color(0xFF5A5A6E),
  gradientEnd: Color(0xFF16151F),
  outline: Color(0xFF000000),
);

/// I30: danh sách skin cố định — 1 free + 3 mua bằng xu + 2 gắn achievement
/// mốc cao (combo tối đa & tổng bàn dọn sạch, mốc khó nhất của mỗi metric).
const kMascotSkins = <MascotSkin>[
  MascotSkin(
    id: 'classic',
    nameKey: 'skin_classic_name',
    palette: classicMascotPalette,
  ),
  MascotSkin(
    id: 'ruby',
    nameKey: 'skin_ruby_name',
    palette: _rubyPalette,
    coinPrice: 300,
  ),
  MascotSkin(
    id: 'emerald',
    nameKey: 'skin_emerald_name',
    palette: _emeraldPalette,
    coinPrice: 600,
  ),
  MascotSkin(
    id: 'sapphire',
    nameKey: 'skin_sapphire_name',
    palette: _sapphirePalette,
    coinPrice: 1000,
  ),
  MascotSkin(
    id: 'aurora',
    nameKey: 'skin_aurora_name',
    palette: _auroraPalette,
    unlockAchievementId: 'combo_25',
  ),
  MascotSkin(
    id: 'obsidian',
    nameKey: 'skin_obsidian_name',
    palette: _obsidianPalette,
    unlockAchievementId: 'clear_400',
  ),
];
