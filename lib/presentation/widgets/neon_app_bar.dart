import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';
import 'neon_icon.dart';

/// Thanh tiêu đề (action bar) neon dùng chung cho mọi màn phụ.
/// Là widget cố định trên cùng — nội dung cuộn nằm dưới, không bị đè.
class NeonAppBar extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const NeonAppBar({
    super.key,
    required this.title,
    this.color = NeonTheme.cyan,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          NeonTheme.s8, NeonTheme.s8, NeonTheme.s8, NeonTheme.s8),
      child: Row(
        children: [
          NeonBackButton(color: color, onTap: onBack),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                shadows: [Shadow(color: color, blurRadius: 14)],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
