import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';
import 'neon_icon.dart';
import 'stroke_text.dart';

/// Thanh tiêu đề (action bar) neon dùng chung cho mọi màn phụ.
/// Là widget cố định trên cùng — nội dung cuộn nằm dưới, không bị đè.
class NeonAppBar extends StatelessWidget {
  final String title;

  /// Defaults to [NeonTheme.cyan] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const NeonAppBar({
    super.key,
    required this.title,
    this.color,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.cyan;
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
            // `FittedBox` chứ không để `StrokeText` tự xuống dòng: thanh này
            // là con KHÔNG co giãn của `Column` bọc ngoài ở mọi màn phụ. Tiêu
            // đề dài (bản dịch dài + cỡ chữ hệ thống lớn) làm nó cao thêm, và
            // `Expanded` bên dưới không cứu được — Sky Shrine tiếng Filipino ở
            // cỡ chữ 1.3 tràn 64px đúng vì vậy.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: StrokeText(
                title,
                fontSize: 23,
                color: Colors.white,
                stroke: color,
                strokeWidth: 4,
                letterSpacing: 1,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
