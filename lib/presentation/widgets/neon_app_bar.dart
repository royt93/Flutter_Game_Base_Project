import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';
import 'neon_icon.dart';
import 'stroke_text.dart';

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
        NeonTheme.s8,
        NeonTheme.s8,
        NeonTheme.s8,
        NeonTheme.s8,
      ),
      child: Row(
        children: [
          NeonBackButton(color: color, onTap: onBack),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: StrokeText(
              title,
              fontSize: 23,
              color: Colors.white,
              stroke: color,
              strokeWidth: 4,
              letterSpacing: 1,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
