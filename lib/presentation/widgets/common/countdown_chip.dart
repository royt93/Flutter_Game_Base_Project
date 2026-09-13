import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// Chip that live-counts down to [target], formatted through the shared
/// [fmtDur] (no reimplemented duration formatting). Ticks every second via
/// an internal `Timer.periodic`, cancels it in [dispose] (and on reaching
/// zero) so it never lingers past unmount, and calls [onDone] exactly once
/// when the countdown reaches zero.
class CountdownChip extends StatefulWidget {
  const CountdownChip({
    super.key,
    required this.target,
    this.onDone,
    this.icon = Icons.timer_outlined,
    this.color,
    this.fontSize = 14,
    this.semanticLabel,
  });

  /// The moment the countdown reaches zero.
  final DateTime target;

  /// Called exactly once, when the countdown reaches zero.
  final VoidCallback? onDone;

  final IconData icon;
  final Color? color;
  final double fontSize;

  /// Overrides the default "Time remaining: mm:ss" Semantics label
  /// (ENH-37). Deliberately NOT a liveRegion — this ticks every second, and
  /// a liveRegion would re-announce it once per second, which is spam, not
  /// help — a screen reader user reads it on demand like any other label.
  final String? semanticLabel;

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  Timer? _timer;
  bool _fired = false;
  late Duration _remaining = _initialRemaining();

  // Rounds UP to the nearest whole second so e.g. target = now + 3s reads
  // "00:03" right at mount instead of instantly truncating to "00:02" from
  // the few ms of real time spent building the first frame.
  Duration _initialRemaining() {
    final d = widget.target.difference(DateTime.now());
    if (d <= Duration.zero) return Duration.zero;
    return Duration(seconds: (d.inMilliseconds / 1000).ceil());
  }

  @override
  void initState() {
    super.initState();
    if (_remaining == Duration.zero) {
      // Already elapsed at mount time — defer the callback past the current
      // build/frame so a parent that reacts by calling setState doesn't hit
      // "setState called during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyDone();
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  // ponytail: decrements 1s per tick rather than re-diffing against
  // `widget.target` with `DateTime.now()` each time — simpler and correctly
  // testable under flutter_test's FakeAsync (which fakes `Timer` but not
  // `DateTime.now()`). Ceiling: if the app is backgrounded and this Timer's
  // ticks get suspended/delayed, the displayed value can lag the real
  // wall-clock target until it catches up. Upgrade path: recompute from
  // `widget.target` using `package:clock`'s `clock.now()` (FakeAsync-aware)
  // if drift-correction across backgrounding becomes a real requirement.
  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    final clamped = next.isNegative ? Duration.zero : next;
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero) {
      _timer?.cancel();
      _notifyDone();
    }
  }

  void _notifyDone() {
    if (_fired) return;
    _fired = true;
    widget.onDone?.call();
  }

  // BUG-30: without this, changing `widget.target` on the same instance
  // (e.g. the player buys a "shorten cooldown" boost) is silently ignored —
  // the countdown keeps ticking toward the stale target until the whole
  // widget gets rebuilt from scratch via a new key.
  @override
  void didUpdateWidget(covariant CountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target == widget.target) return;

    _timer?.cancel();
    _fired = false;
    _remaining = _initialRemaining();
    if (_remaining == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyDone();
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? NeonTheme.red;
    return Semantics(
      label: widget.semanticLabel ?? 'Time remaining: ${fmtDur(_remaining)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: c, size: widget.fontSize + 4),
            const SizedBox(width: 4),
            Text(
              fmtDur(_remaining),
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
