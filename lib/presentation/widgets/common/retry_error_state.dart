import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/fnv1a.dart';
import '../../../core/utils/sdk_result.dart';
import 'async_common_button.dart';
import 'empty_state_placeholder.dart';
import 'toast_banner.dart';

/// Data-driven "this failed, here's why, try again" panel — composed from
/// [EmptyStatePlaceholder] (same icon-badge/title/message chrome every other
/// empty/error state in this kit already uses) plus an optional
/// [AsyncCommonButton] retry action, which is what actually gives "rapid tap
/// doesn't run the retry twice" for free (see `async_common_button.dart`'s
/// own re-entry guard) — this widget adds no tap-guarding of its own.
///
/// [message] is the only text ever rendered — [RetryErrorState.fromSdkFailure]
/// only ever reads [SdkFailure.message] (documented there as the safe,
/// consumer-facing string), never `.cause`/`.stackTrace`. [code] is a
/// separate, optional, tappable diagnostic string (tap copies it to the
/// clipboard) for a support conversation — [fromSdkFailure] derives it
/// deterministically from `kind`+`message` via [fnv1aHash], so the same
/// error always shows the same code.
///
/// [onRetry] left `null` hides the retry button entirely rather than
/// showing a button that does nothing.
///
/// [compact] controls layout only: `false` (default) centers the panel to
/// fill whatever space the caller gives it (a whole screen replaced by an
/// error state); `true` renders just the column, unwrapped, for embedding
/// inline (e.g. inside a smaller panel/list empty state) — no change to
/// [EmptyStatePlaceholder] itself was needed for either variant.
class RetryErrorState extends StatelessWidget {
  const RetryErrorState({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.title,
    this.code,
    this.onRetry,
    this.retryLabel,
    this.extraAction,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? code;
  final Future<void> Function()? onRetry;
  final String? retryLabel;

  /// A second, caller-supplied action rendered below retry/code — e.g. an
  /// "Open network settings" button for a [SdkErrorKind.network] failure.
  /// The kit doesn't know what that action should do for a given app, so
  /// it's a plain slot rather than a named "offline button" with baked-in
  /// behavior.
  final Widget? extraAction;
  final Color? color;
  final bool compact;

  static IconData _iconFor(SdkErrorKind kind) => switch (kind) {
    SdkErrorKind.network => Icons.wifi_off,
    SdkErrorKind.storage => Icons.save_alt,
    SdkErrorKind.platform => Icons.phone_android,
    SdkErrorKind.conflict => Icons.sync_problem,
    SdkErrorKind.validation => Icons.warning_amber,
    SdkErrorKind.unknown => Icons.error_outline,
  };

  static String _titleFor(SdkErrorKind kind) => switch (kind) {
    SdkErrorKind.network => 'Connection problem',
    SdkErrorKind.storage => 'Storage error',
    SdkErrorKind.platform => 'Platform error',
    SdkErrorKind.conflict => 'Sync conflict',
    SdkErrorKind.validation => 'Something needs fixing',
    SdkErrorKind.unknown => 'Something went wrong',
  };

  /// Deterministic: same [SdkFailure.kind] + [SdkFailure.message] always
  /// produces the same code, across app restarts/platforms — [fnv1aHash] is
  /// a pure, dependency-free hash (see its own doc for why, over
  /// `String.hashCode`, which isn't guaranteed stable).
  static String _codeFor(SdkFailure failure) {
    final hash = fnv1aHash('${failure.kind.name}:${failure.message}');
    return '${failure.kind.name.toUpperCase()}-${hash.toRadixString(16).toUpperCase()}';
  }

  static RetryErrorState fromSdkFailure(
    SdkFailure failure, {
    Future<void> Function()? onRetry,
    String? retryLabel,
    Widget? extraAction,
    Color? color,
    bool compact = false,
  }) => RetryErrorState(
    icon: _iconFor(failure.kind),
    title: _titleFor(failure.kind),
    message: failure.message,
    code: _codeFor(failure),
    onRetry: onRetry,
    retryLabel: retryLabel,
    extraAction: extraAction,
    color: color,
    compact: compact,
  );

  Future<void> _copyCode(BuildContext context) async {
    final value = code;
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ToastBanner.show(context, message: 'Copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.red;
    final hasAction = onRetry != null || extraAction != null || code != null;
    final placeholder = EmptyStatePlaceholder(
      icon: icon,
      color: c,
      title: title,
      message: message,
      action: !hasAction
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetry != null)
                  AsyncCommonButton(
                    label: retryLabel ?? 'Retry',
                    onPressed: onRetry!,
                  ),
                if (extraAction != null) ...[
                  const SizedBox(height: NeonTheme.s8),
                  extraAction!,
                ],
                if (code != null) ...[
                  const SizedBox(height: NeonTheme.s8),
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => _copyCode(context),
                      child: Semantics(
                        button: true,
                        label: 'Diagnostic code $code, tap to copy',
                        child: Text(
                          code!,
                          style: TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
    // liveRegion so a screen reader announces the error the moment it
    // replaces loading/content — same reasoning as ToastBanner/
    // CurrencyCounter's own liveRegion use in this kit.
    final announced = Semantics(
      liveRegion: true,
      label: [if (title != null) title, message].join('. '),
      child: placeholder,
    );
    if (compact) return announced;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NeonTheme.s24),
        child: announced,
      ),
    );
  }
}
