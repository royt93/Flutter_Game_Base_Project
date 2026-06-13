import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_icon.dart';

/// Màn hướng dẫn: cách chơi, gem đặc biệt, combo, các chế độ.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(NeonTheme.s16),
                child: Row(
                  children: [
                    const NeonBackButton(color: NeonTheme.magenta),
                    const SizedBox(width: NeonTheme.s8),
                    Text('guide'.tr, style: _title(24, NeonTheme.magenta)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(
                      NeonTheme.s24, NeonTheme.s8, NeonTheme.s24, NeonTheme.s24),
                  children: [
                    _section(
                      color: NeonTheme.cyan,
                      icon: Icons.touch_app_rounded,
                      title: 'guide_howto_title'.tr,
                      body: 'guide_howto_body'.tr,
                    ),
                    _section(
                      color: NeonTheme.lime,
                      icon: Icons.auto_awesome_rounded,
                      title: 'guide_special_title'.tr,
                      children: [
                        _bullet(NeonTheme.cyan, Icons.swap_horiz_rounded,
                            'guide_striped'.tr, 'guide_striped_desc'.tr),
                        _bullet(NeonTheme.orange, Icons.brightness_7_rounded,
                            'guide_bomb'.tr, 'guide_bomb_desc'.tr),
                        _bullet(NeonTheme.magenta, Icons.blur_circular_rounded,
                            'guide_rainbow'.tr, 'guide_rainbow_desc'.tr),
                      ],
                    ),
                    _section(
                      color: NeonTheme.magenta,
                      icon: Icons.bolt_rounded,
                      title: 'guide_combo_title'.tr,
                      body: 'guide_combo_body'.tr,
                    ),
                    _section(
                      color: NeonTheme.purple,
                      icon: Icons.flag_rounded,
                      title: 'guide_modes_title'.tr,
                      children: [
                        _bullet(NeonTheme.cyan, Icons.star_rounded, '',
                            'guide_mode_score'.tr),
                        _bullet(NeonTheme.lime, Icons.diamond_rounded, '',
                            'guide_mode_collect'.tr),
                        _bullet(NeonTheme.magenta, Icons.blur_on_rounded, '',
                            'guide_mode_jelly'.tr),
                      ],
                    ),
                    _section(
                      color: NeonTheme.yellow,
                      icon: Icons.lightbulb_rounded,
                      title: '★',
                      body: 'guide_stuck'.tr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _title(double size, Color color) => TextStyle(
        fontFamily: 'Orbitron',
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        shadows: [Shadow(color: color, blurRadius: 14)],
      );

  Widget _section({
    required Color color,
    required IconData icon,
    required String title,
    String? body,
    List<Widget>? children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s16),
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
        boxShadow: NeonTheme.glow(color, blur: 7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeonIcon(icon, color: color, size: 22),
              const SizedBox(width: NeonTheme.s8),
              Expanded(child: Text(title, style: _title(17, color))),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: NeonTheme.s8),
            Text(body, style: _bodyStyle),
          ],
          if (children != null) ...[
            const SizedBox(height: NeonTheme.s8),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _bullet(Color color, IconData icon, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeonTheme.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeonIcon(icon, color: color, size: 20),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                Text(desc, style: _bodyStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final TextStyle _bodyStyle = const TextStyle(
    fontFamily: 'Orbitron',
    color: Colors.white70,
    fontSize: 13,
    height: 1.45,
  );
}
