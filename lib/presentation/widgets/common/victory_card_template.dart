import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/neon_theme.dart';
import '../stroke_text.dart';
import 'avatar_frame.dart';
import 'panel_card.dart';

/// Pre-built "victory card" a game can drop straight in for a level-complete
/// / result screen, then screenshot + share via the existing pipeline in
/// `share_helper.dart`. This widget only renders — it has no idea a share
/// pipeline exists.
///
/// It has no access to accounts, a backend, or a deep-link scheme, so every
/// piece of dynamic content is caller-supplied: [statLines] are plain strings
/// the consumer app has already worded/localized/computed (this package
/// never invents comparison stats like "faster than 92% of players"), and
/// [qrData] — if the consumer has an invite/deep-link system at all — is
/// just the string to render as a QR code; leave it null for a plain
/// stats/avatar card with zero QR-related cost.
///
/// ### Wiring to the share pipeline
/// This widget does not wrap itself in a `RepaintBoundary` and does not call
/// `share_helper.dart` itself. To share it:
/// ```dart
/// final cardKey = GlobalKey();
/// // ... build once, e.g. in a hidden overlay or the widget tree:
/// RepaintBoundary(
///   key: cardKey,
///   child: VictoryCardTemplate(
///     title: 'Level 50 Complete!',
///     statLines: ['Score: 12,340', 'Time: 01:23'],
///   ),
/// ),
/// // ... then, on the Share button's onTap:
/// await shareScoreCard(boundaryKey: cardKey, levelText: 'Level 50 Complete!');
/// ```
/// See `example/lib/screens/widget_showcase_screen.dart` for a full working
/// example of this wiring.
class VictoryCardTemplate extends StatelessWidget {
  const VictoryCardTemplate({
    super.key,
    required this.title,
    required this.statLines,
    this.avatar,
    this.qrData,
    this.accentColor,
  });

  /// Caller-supplied headline, e.g. "Level 50 Complete!" — no i18n baked in.
  final String title;

  /// Caller-supplied stat strings (already worded/localized/computed by the
  /// consumer app), rendered as a simple vertical list.
  final List<String> statLines;

  /// Optional avatar slot — an arbitrary widget (image/icon/initials),
  /// centered near the top and framed via [AvatarFrame]. This widget doesn't
  /// fetch or manage avatars itself.
  final Widget? avatar;

  /// Optional caller-supplied string to render as a QR code near the bottom
  /// (e.g. an invite link/deep link the consuming app already has). Renders
  /// nothing when null or empty — this widget doesn't invent an invite
  /// system, it only renders a QR code for a string it's given.
  final String? qrData;

  /// Defaults to [NeonTheme.gold] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? NeonTheme.gold;
    final hasQr = qrData != null && qrData!.isNotEmpty;
    return PanelCard(
      borderColor: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (avatar != null) ...[
            AvatarFrame(color: accent, size: 88, child: avatar!),
            const SizedBox(height: NeonTheme.s16),
          ],
          StrokeText(title, fontSize: 22, color: accent),
          const SizedBox(height: NeonTheme.s16),
          for (final line in statLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (hasQr) ...[
            const SizedBox(height: NeonTheme.s16),
            QrImageView(data: qrData!, size: 96),
            const SizedBox(height: NeonTheme.s8),
            Text(
              'Scan to play',
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
