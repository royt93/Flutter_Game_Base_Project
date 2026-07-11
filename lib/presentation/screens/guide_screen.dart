import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Giải thích luật chơi Pop Star: chạm nhóm ô cùng màu liền kề để nổ.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _rules = [
    (
      Icons.touch_app_rounded,
      NeonTheme.cyan,
      'Tap a group',
      'Tap any group of 2 or more connected blocks of the same color to pop them.',
    ),
    (
      Icons.trending_up_rounded,
      NeonTheme.magenta,
      'Bigger is better',
      'Popping a bigger group scores more points: score = 5 × n × (n − 1).',
    ),
    (
      Icons.arrow_downward_rounded,
      NeonTheme.lime,
      'Gravity & collapse',
      'Blocks above a pop fall down to fill the gap, then empty columns shift left.',
    ),
    (
      Icons.emoji_events_rounded,
      NeonTheme.yellow,
      'Clear the board',
      'Clear every block on the board for a big bonus at the end of the level.',
    ),
    (
      Icons.block_rounded,
      NeonTheme.orange,
      'No moves left',
      'The level ends once no group of 2+ remains — reach the target score to earn stars.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              const NeonAppBar(title: 'How to Play', color: NeonTheme.lime),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  itemCount: _rules.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: NeonTheme.s16),
                  itemBuilder: (context, i) {
                    final (icon, color, title, body) = _rules[i];
                    return Container(
                      padding: const EdgeInsets.all(NeonTheme.s16),
                      decoration: BoxDecoration(
                        color: NeonTheme.panel.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 28),
                          const SizedBox(width: NeonTheme.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(color: color, blurRadius: 8),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
