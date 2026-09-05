import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Styled list row for a settings row / leaderboard row / etc — candy-themed
/// replacement for the default Material [ListTile]. When [filled] is true the
/// row gets a [NeonTheme.card] background + rounded corners (a standalone
/// "card row"); when false the background is transparent (for rows already
/// inside a [PanelCard] or other container, e.g. a divided list).
class CommonListTile extends StatelessWidget {
  const CommonListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.filled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s16, vertical: NeonTheme.s16),
      decoration: filled
          ? BoxDecoration(
              color: NeonTheme.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: NeonTheme.drop(y: 2, blur: 6),
            )
          : null,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: NeonTheme.s16)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: NeonTheme.ink, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: NeonTheme.s16), trailing!],
        ],
      ),
    );
    return onTap == null ? row : PressableScale(onTap: onTap, child: row);
  }
}
