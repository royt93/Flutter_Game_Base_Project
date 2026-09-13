import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Bold section title + optional trailing action (e.g. a "See all" button) —
/// for grouping sections of a screen ("Daily Rewards", "Leaderboard", ...).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // ENH-37: header: true lets a screen reader jump between
          // sections (TalkBack's "headings" navigation gesture), same as
          // an <h2> would for sighted structure.
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
