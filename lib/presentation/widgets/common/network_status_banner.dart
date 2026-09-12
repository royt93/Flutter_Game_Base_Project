import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Thin banner pinned to the top of the screen, shown while [connected] is
/// false (e.g. so a silent cloud-save failure isn't a confusing "why didn't
/// my progress save?" moment).
///
/// Pure presentation: it takes network state from the caller — either a
/// plain [connected] bool (caller flips it, same "caller owns the state"
/// convention as [LoadingOverlay]) or, via [NetworkStatusBanner.stream], a
/// `Stream<bool>` — and never reaches for a connectivity package itself, so
/// the kit gains no new dependency and the app decides its own signal
/// source.
///
/// Built entirely from implicit animations ([AnimatedSize]/[AnimatedOpacity])
/// rather than an owned `AnimationController` — nothing to leak: both stop
/// ticking on their own once the target value is reached.
class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({
    super.key,
    required this.connected,
    this.offlineMessage = 'No internet connection',
    this.duration = const Duration(milliseconds: 250),
  });

  final bool connected;
  final String offlineMessage;
  final Duration duration;

  /// Same widget, driven by a `Stream<bool>` instead of a plain bool.
  static Widget stream({
    Key? key,
    required Stream<bool> connected,
    bool initialConnected = true,
    String offlineMessage = 'No internet connection',
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return StreamBuilder<bool>(
      initialData: initialConnected,
      stream: connected,
      builder: (context, snapshot) => NetworkStatusBanner(
        key: key,
        connected: snapshot.data ?? initialConnected,
        offlineMessage: offlineMessage,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final show = !connected;
    final effectiveDuration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : duration;
    return AnimatedSize(
      duration: effectiveDuration,
      // Flat/status curve (IDEA-21, NeonTheme.reducedMotion's doc) — no
      // overshoot, this is a warning banner, not a celebration moment.
      // Explicit rather than relying on the implicit default of
      // Curves.linear.
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: effectiveDuration,
        curve: Curves.easeOut,
        opacity: show ? 1 : 0,
        child: !show
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                color: NeonTheme.red,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: NeonTheme.s8,
                      horizontal: NeonTheme.s16,
                    ),
                    child: Text(
                      offlineMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
