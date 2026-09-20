import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

/// [AsyncCommonButton]'s current phase.
enum AsyncButtonStatus { idle, loading, success, error }

/// A [CommonButton] wrapper that drives itself through
/// [AsyncButtonStatus.loading]/`success`/`error` around an async [onPressed]
/// callback — the state machine [BackupRestorePanel] and similar
/// hand-rolled per-widget before this existed (FEAT-50). Ignores a tap while
/// not [AsyncButtonStatus.idle] (a rapid double-tap can't start a second
/// [onPressed] call, and a tap during the success/error cooldown is ignored
/// too, not queued).
///
/// [onPressed] left `null` disables the button (mirrors [CommonButton]'s
/// own `onTap: null` convention) — for a business-rule gate (e.g. "select
/// at least one option first"), not for hiding that async work is in
/// flight (that's what [AsyncButtonStatus.loading] is for).
class AsyncCommonButton extends StatefulWidget {
  const AsyncCommonButton({
    super.key,
    this.label,
    this.icon,
    this.variant = CommonButtonVariant.primary,
    required this.onPressed,
    this.color,
    this.width,
    this.semanticLabel,
    this.timeout,
    this.successIcon = Icons.check_circle,
    this.errorIcon = Icons.error,
    this.successDuration = const Duration(seconds: 1),
    this.errorDuration = const Duration(seconds: 2),
    this.loadingAnnouncement = 'Loading',
    this.successAnnouncement,
    this.errorAnnouncement = 'Action failed',
  });

  final String? label;
  final IconData? icon;
  final CommonButtonVariant variant;
  final Future<void> Function()? onPressed;
  final Color? color;
  final double? width;
  final String? semanticLabel;

  /// If [onPressed] hasn't completed within this, it's treated as an error
  /// (a [TimeoutException] is indistinguishable from any other thrown error
  /// here — both land in [AsyncButtonStatus.error]).
  final Duration? timeout;

  final IconData successIcon;
  final IconData errorIcon;

  /// How long [AsyncButtonStatus.success]/`error` is shown before the
  /// button reverts to idle and becomes tappable again.
  final Duration successDuration;
  final Duration errorDuration;

  final String loadingAnnouncement;
  final String? successAnnouncement;
  final String errorAnnouncement;

  @override
  State<AsyncCommonButton> createState() => _AsyncCommonButtonState();
}

class _AsyncCommonButtonState extends State<AsyncCommonButton> {
  AsyncButtonStatus _status = AsyncButtonStatus.idle;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_status != AsyncButtonStatus.idle || widget.onPressed == null) return;
    setState(() => _status = AsyncButtonStatus.loading);
    _run();
  }

  Future<void> _run() async {
    try {
      final future = widget.onPressed!();
      final timeout = widget.timeout;
      await (timeout == null ? future : future.timeout(timeout));
      if (!mounted) return;
      setState(() => _status = AsyncButtonStatus.success);
      _scheduleRevert(widget.successDuration);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = AsyncButtonStatus.error);
      _scheduleRevert(widget.errorDuration);
    }
  }

  void _scheduleRevert(Duration delay) {
    _revertTimer?.cancel();
    _revertTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _status = AsyncButtonStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = NeonTheme.reducedMotion(context);
    final displayIcon = switch (_status) {
      AsyncButtonStatus.success => widget.successIcon,
      AsyncButtonStatus.error => widget.errorIcon,
      AsyncButtonStatus.idle || AsyncButtonStatus.loading => widget.icon,
    };
    final announcement = switch (_status) {
      AsyncButtonStatus.loading => widget.loadingAnnouncement,
      AsyncButtonStatus.success => widget.successAnnouncement,
      AsyncButtonStatus.error => widget.errorAnnouncement,
      AsyncButtonStatus.idle => null,
    };
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedSwitcher(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
          child: CommonButton(
            key: ValueKey(_status),
            label: widget.label,
            icon: displayIcon,
            variant: widget.variant,
            color: widget.color,
            width: widget.width,
            semanticLabel: widget.semanticLabel,
            loading: _status == AsyncButtonStatus.loading,
            onTap:
                (_status == AsyncButtonStatus.idle && widget.onPressed != null)
                ? _handleTap
                : null,
          ),
        ),
        if (announcement != null)
          Semantics(
            liveRegion: true,
            label: announcement,
            excludeSemantics: true,
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}
