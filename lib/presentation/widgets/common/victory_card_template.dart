import 'dart:math' as math;

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
    this.qrCaption = 'Scan to play',
    this.starsEarned,
    this.totalStars = 3,
    this.starStaggerDuration = const Duration(milliseconds: 250),
    this.onStarPopped,
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

  /// Caption shown under the QR code (only when [qrData] is given). Defaults
  /// to the hardcoded English 'Scan to play' — the caller's own localized
  /// copy overrides it (ENH-39; this package doesn't own app-facing
  /// translation keys for game-specific copy like this).
  final String qrCaption;

  /// Optional earned-star count; when set, stars animate in sequence.
  final int? starsEarned;

  /// Number of stars available when [starsEarned] is set.
  final int totalStars;

  /// Stagger delay between sequential star pops.
  final Duration starStaggerDuration;

  /// Callback fired when each individual star completes its entrance pop.
  final ValueChanged<int>? onStarPopped;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? NeonTheme.gold;
    final hasQr = qrData != null && qrData!.isNotEmpty;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NeonTheme.reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: PanelCard(
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
            if (starsEarned != null) ...[
              const SizedBox(height: NeonTheme.s8),
              _VictoryStarsRow(
                earned: starsEarned!.clamp(0, totalStars),
                total: totalStars,
                staggerDuration: starStaggerDuration,
                onStarPopped: onStarPopped,
              ),
            ],
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
              // BUG-33: a QR code needs high contrast against ITS OWN
              // background as a scanning requirement, not a theme choice —
              // QrImageView draws black modules on a transparent background
              // by default, which becomes unreadable (near-invisible) once
              // NeonTheme.dark makes the card's own background dark. Fixed
              // white, regardless of NeonTheme.dark, with enough padding to
              // keep the QR spec's "quiet zone" margin around the modules.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(data: qrData!, size: 96),
              ),
              const SizedBox(height: NeonTheme.s8),
              Text(
                qrCaption,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VictoryStarsRow extends StatefulWidget {
  const _VictoryStarsRow({
    required this.earned,
    required this.total,
    required this.staggerDuration,
    this.onStarPopped,
  });

  final int earned;
  final int total;
  final Duration staggerDuration;
  final ValueChanged<int>? onStarPopped;

  @override
  State<_VictoryStarsRow> createState() => _VictoryStarsRowState();
}

class _VictoryStarsRowState extends State<_VictoryStarsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Set<int> _notified = {};
  static const _popDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    final totalUs =
        widget.staggerDuration.inMicroseconds *
            (math.max(1, widget.earned) - 1) +
        _popDuration.inMicroseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: totalUs),
    )..addListener(_checkCallbacks);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (NeonTheme.reducedMotion(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });
  }

  void _checkCallbacks() {
    final totalUs = _controller.duration?.inMicroseconds ?? 0;
    if (totalUs == 0) return;
    for (var i = 0; i < widget.earned; i++) {
      final startRatio = (widget.staggerDuration.inMicroseconds * i) / totalUs;
      if (_controller.value >= startRatio && _notified.add(i)) {
        widget.onStarPopped?.call(i);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = NeonTheme.reducedMotion(context);
    final totalUs = _controller.duration?.inMicroseconds ?? 1;

    return Semantics(
      label: '${widget.earned} of ${widget.total} stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.total; i++) ...[
            Builder(
              builder: (context) {
                final isFilled = i < widget.earned;
                final icon = Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: isFilled ? NeonTheme.gold : NeonTheme.muted,
                  shadows: isFilled
                      ? [Shadow(color: NeonTheme.gold, blurRadius: 12)]
                      : null,
                );

                if (!isFilled || isReduced) return icon;

                final startUs = widget.staggerDuration.inMicroseconds * i;
                final endUs = startUs + _popDuration.inMicroseconds;
                final startRatio = (startUs / totalUs).clamp(0.0, 1.0);
                final endRatio = (endUs / totalUs).clamp(0.0, 1.0);

                final anim = CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    startRatio,
                    endRatio,
                    curve: Curves.easeOutBack,
                  ),
                );

                return ScaleTransition(scale: anim, child: icon);
              },
            ),
            if (i < widget.total - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
