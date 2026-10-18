import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import '../neon_dialog.dart';
import 'common_button.dart';

/// A presentation-only popup showing coins earned while the player was away
/// (FEAT-140). The caller gets the actual earnings from
/// `OfflineProgressionService.claim()` and grants them through its own wallet.
class OfflineEarningsPopup extends StatefulWidget {
  OfflineEarningsPopup({
    super.key,
    required this.coins,
    required this.elapsed,
    required this.onCollect,
    this.ratePerSecond,
    this.onDoubleTap,
    this.title = 'Welcome Back!',
    this.message,
    this.collectLabel = 'Collect',
    this.doubleLabel = 'Double 2x',
    this.semanticLabel,
    this.showActions = true,
  }) {
    if (coins < 0) {
      throw ArgumentError.value(coins, 'coins', 'must be non-negative');
    }
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'must be non-negative');
    }
    if (ratePerSecond != null &&
        (!ratePerSecond!.isFinite || ratePerSecond! < 0)) {
      throw ArgumentError.value(
        ratePerSecond,
        'ratePerSecond',
        'must be finite and non-negative',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (collectLabel.trim().isEmpty) {
      throw ArgumentError.value(
        collectLabel,
        'collectLabel',
        'must not be empty',
      );
    }
    if (doubleLabel.trim().isEmpty) {
      throw ArgumentError.value(
        doubleLabel,
        'doubleLabel',
        'must not be empty',
      );
    }
  }

  final int coins;
  final Duration elapsed;
  final double? ratePerSecond;
  final VoidCallback onCollect;
  final VoidCallback? onDoubleTap;
  final String title;
  final String? message;
  final String collectLabel;
  final String doubleLabel;
  final String? semanticLabel;
  final bool showActions;

  /// Displays an offline earnings popup with the standard in-tree dialog
  /// pattern, so it also works above a full-screen Flame `GameWidget`.
  static Future<void> show(
    BuildContext context, {
    required int coins,
    required Duration elapsed,
    required VoidCallback onCollect,
    double? ratePerSecond,
    VoidCallback? onDoubleTap,
    String title = 'Welcome Back!',
    String? message,
    String collectLabel = 'Collect',
    String doubleLabel = 'Double 2x',
    String? semanticLabel,
  }) {
    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: NeonTheme.gold,
      icon: Icons.monetization_on_rounded,
      content: OfflineEarningsPopup(
        coins: coins,
        elapsed: elapsed,
        ratePerSecond: ratePerSecond,
        onCollect: onCollect,
        onDoubleTap: onDoubleTap,
        title: title,
        message: message,
        collectLabel: collectLabel,
        doubleLabel: doubleLabel,
        semanticLabel: semanticLabel,
        showActions: false,
      ),
      actions: [
        NeonDialogAction(
          label: collectLabel,
          color: NeonTheme.gold,
          onTap: onCollect,
        ),
        if (onDoubleTap != null)
          NeonDialogAction(
            label: doubleLabel,
            color: NeonTheme.orange,
            onTap: onDoubleTap,
          ),
      ],
    );
  }

  @override
  State<OfflineEarningsPopup> createState() => _OfflineEarningsPopupState();
}

class _OfflineEarningsPopupState extends State<OfflineEarningsPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _counterController;
  late final Animation<double> _counterAnimation;
  late int _displayedCoins;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOut,
    );
    _displayedCoins = 0;
    _counterController.addListener(_handleTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = NeonTheme.reducedMotion(context);
    if (_reducedMotion) {
      skipToEnd();
    } else if (_displayedCoins == 0 &&
        widget.coins > 0 &&
        !_counterController.isAnimating) {
      _counterController.forward(from: 0);
    }
  }

  void _handleTick() {
    final next = (widget.coins * _counterAnimation.value).round();
    if (next != _displayedCoins) {
      setState(() => _displayedCoins = next);
    }
  }

  /// Instantly settles the counter to [coins]. Tapping the count offers the
  /// classic "skip the celebration" shortcut without stealing button taps.
  void skipToEnd() {
    if (_displayedCoins == widget.coins && !_counterController.isAnimating) {
      return;
    }
    _counterController
      ..stop()
      ..value = 1;
    setState(() => _displayedCoins = widget.coins);
  }

  @override
  void didUpdateWidget(covariant OfflineEarningsPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coins != widget.coins) {
      if (_reducedMotion) {
        _counterController
          ..stop()
          ..value = 1;
        _displayedCoins = widget.coins;
      } else {
        _displayedCoins = 0;
        _counterController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _counterController.removeListener(_handleTick);
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsedLabel = fmtDurDays(widget.elapsed);
    final defaultMessage =
        'While you were away ($elapsedLabel), your game earned';
    final rate = widget.ratePerSecond;
    final semanticsLabel =
        widget.semanticLabel ??
        '${widget.title}. ${fmtNum(widget.coins)} coins earned in $elapsedLabel.';

    return Semantics(
      key: const ValueKey('offlineEarningsSemantics'),
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message != null || widget.title != 'Welcome Back!') ...[
              Text(
                widget.message ?? defaultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
            ] else ...[
              Text(
                defaultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
            ],
            GestureDetector(
              key: const ValueKey('offlineEarningsCounterTap'),
              behavior: HitTestBehavior.opaque,
              onTap: skipToEnd,
              child: RepaintBoundary(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: NeonTheme.gold,
                      size: 38,
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Text(
                      fmtNum(_displayedCoins),
                      key: const ValueKey('offlineEarningsCoinCount'),
                      style: TextStyle(
                        color: NeonTheme.gold,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: NeonTheme.glow(NeonTheme.gold, blur: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            Text(
              'Offline time: $elapsedLabel',
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Production: ${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} coins/s',
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (widget.showActions && widget.onDoubleTap != null) ...[
              const SizedBox(height: NeonTheme.s16),
              CommonButton(
                key: const ValueKey('offlineEarningsDoubleBtn'),
                label: widget.doubleLabel,
                color: NeonTheme.orange,
                onTap: widget.onDoubleTap,
              ),
            ],
            if (widget.showActions) ...[
              const SizedBox(height: NeonTheme.s8),
              CommonButton(
                key: const ValueKey('offlineEarningsCollectBtn'),
                label: widget.collectLabel,
                color: NeonTheme.gold,
                onTap: widget.onCollect,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
