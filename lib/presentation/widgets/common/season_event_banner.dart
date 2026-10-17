import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/season_event_service.dart';
import '../../../core/utils/format.dart';

/// A prominent live-ops banner for seasonal events and tournaments (FEAT-130).
///
/// Features:
/// - Event countdown ticking every second using [fmtDurDays] (e.g. "3d 4h" or "01:23:45").
/// - Milestone progress bar tracking progress toward the next event reward.
/// - Named constructor [SeasonEventBanner.fromWindow] binding directly to a
///   [SeasonEventWindow] from `SeasonEventService`.
/// - Automatic expiration transition: when [endsAt] is reached, the countdown flips
///   to "Ended", taps are disabled, and [onEnded] is invoked once.
/// - Accessibility: Semantics merges title, countdown/ended status, and milestone progress.
class SeasonEventBanner extends StatefulWidget {
  SeasonEventBanner({
    super.key,
    required this.title,
    required this.endsAt,
    required this.progress,
    this.onTap,
    this.onEnded,
    this.subtitle,
    this.milestoneLabel,
    this.icon,
    this.iconData = Icons.celebration_rounded,
    this.color,
    this.height = 100,
    this.width,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (!progress.isFinite || progress < 0.0 || progress > 1.0) {
      throw ArgumentError.value(
        progress,
        'progress',
        'must be finite and between 0.0 and 1.0',
      );
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be finite and positive',
      );
    }
    if (width != null && (!width!.isFinite || width! <= 0)) {
      throw ArgumentError.value(width, 'width', 'must be finite and positive');
    }
  }

  /// Convenience constructor binding directly to a [SeasonEventWindow].
  SeasonEventBanner.fromWindow({
    Key? key,
    required String title,
    required SeasonEventWindow window,
    required double progress,
    VoidCallback? onTap,
    VoidCallback? onEnded,
    String? subtitle,
    String? milestoneLabel,
    Widget? icon,
    IconData iconData = Icons.celebration_rounded,
    Color? color,
    double height = 100,
    double? width,
  }) : this(
         key: key,
         title: title,
         endsAt: window.end,
         progress: progress,
         onTap: onTap,
         onEnded: onEnded,
         subtitle: subtitle,
         milestoneLabel: milestoneLabel,
         icon: icon,
         iconData: iconData,
         color: color,
         height: height,
         width: width,
       );

  final String title;
  final DateTime endsAt;
  final double progress;
  final VoidCallback? onTap;
  final VoidCallback? onEnded;
  final String? subtitle;
  final String? milestoneLabel;
  final Widget? icon;
  final IconData iconData;
  final Color? color;
  final double height;
  final double? width;

  @override
  State<SeasonEventBanner> createState() => _SeasonEventBannerState();
}

class _SeasonEventBannerState extends State<SeasonEventBanner> {
  Timer? _timer;
  late Duration _remaining;
  bool _endedNotified = false;

  Duration _calculateRemaining() {
    final diff = widget.endsAt.difference(DateTime.now());
    if (diff <= Duration.zero) return Duration.zero;
    return Duration(seconds: (diff.inMilliseconds / 1000).ceil());
  }

  bool get isEnded => _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    if (isEnded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyEnded();
      });
    } else {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant SeasonEventBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _timer?.cancel();
      _remaining = _calculateRemaining();
      _endedNotified = false;
      if (isEnded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyEnded();
        });
      } else {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    final clamped = next.isNegative ? Duration.zero : next;
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero) {
      _timer?.cancel();
      _notifyEnded();
    }
  }

  void _notifyEnded() {
    if (_endedNotified) return;
    _endedNotified = true;
    widget.onEnded?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? NeonTheme.purple;
    final ended = isEnded;
    final primary = ended ? NeonTheme.muted : themeColor;
    final reducedMotion = NeonTheme.reducedMotion(context);
    final percent = (widget.progress * 100).round();
    final timeText = ended ? 'Ended' : fmtDurDays(_remaining);

    final semanticText =
        '${widget.title}, ${ended ? 'event ended' : 'ends in $timeText'}, $percent percent milestone progress';

    final bannerContent = Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: ended ? 0.25 : 0.6),
          width: 2,
        ),
        boxShadow: ended
            ? NeonTheme.drop(blur: 4)
            : NeonTheme.glow(primary, blur: 10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeonTheme.cardAlt,
              border: Border.all(
                color: primary.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child:
                widget.icon ?? Icon(widget.iconData, color: primary, size: 28),
          ),
          const SizedBox(width: 12),
          // Event details & progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    // Countdown chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: NeonTheme.cardAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: primary),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            key: const ValueKey('seasonEventCountdownText'),
                            style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: NeonTheme.s8),
                // Progress bar with milestone label
                Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          final fill = (barWidth * widget.progress).clamp(
                            0.0,
                            barWidth,
                          );
                          return Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: NeonTheme.cardAlt,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: [
                                AnimatedContainer(
                                  duration: reducedMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  width: fill,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.milestoneLabel != null) ...[
                      const SizedBox(width: NeonTheme.s8),
                      Text(
                        widget.milestoneLabel!,
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.onTap != null && !ended) ...[
            const SizedBox(width: NeonTheme.s8),
            Icon(
              Icons.chevron_right_rounded,
              color: NeonTheme.inkSoft,
              size: 24,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      button: widget.onTap != null && !ended,
      label: semanticText,
      value: '$percent%',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('seasonEventBannerTap'),
          behavior: HitTestBehavior.opaque,
          onTap: ended ? null : widget.onTap,
          child: RepaintBoundary(child: bannerContent),
        ),
      ),
    );
  }
}
