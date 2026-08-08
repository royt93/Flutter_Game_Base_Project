import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/mascot_skins.dart';
import 'star_mascot.dart';

/// Ô hiển thị 1 mascot skin (khoá/mở khoá) — dùng chung giữa
/// `trophy_room_screen.dart` và `sticker_album_screen.dart`, trước đây mỗi
/// màn tự định nghĩa 1 bản riêng giống hệt nhau.
class MascotSkinTile extends StatelessWidget {
  const MascotSkinTile({
    super.key,
    required this.skin,
    required this.unlocked,
    this.mascotSize = 56,
  });

  final MascotSkin skin;
  final bool unlocked;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? NeonTheme.magenta : NeonTheme.inkSoft;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: unlocked ? 2 : 1.5),
        boxShadow: unlocked ? NeonTheme.glow(color) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1.0 : 0.45,
            child: StarMascot(size: mascotSize, palette: skin.palette),
          ),
          const SizedBox(height: 4),
          Text(
            skin.nameKey.tr,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
