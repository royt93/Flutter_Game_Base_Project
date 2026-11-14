import 'package:flutter/material.dart';

import '../../../core/app_version_gate.dart';
import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

/// Wraps [child] with a blocking/dismissible overlay driven by
/// [decision] — takes plain data (same "widgets take data, caller owns the
/// service" convention as `EnergyBar`/`LevelSelectGrid`), never reads
/// `AppVersionGateController` itself.
///
/// - [GateDecision.ok]: renders only [child].
/// - [GateDecision.maintenance] / [GateDecision.forceUpdate]: full-screen
///   blocking panel, back button intercepted (`PopScope(canPop: false)`) —
///   never dismissible.
/// - [GateDecision.softUpdate]: same panel but dismissible (a "Để sau"
///   button and the system back button both work), calling [onSoftDismiss]
///   so the caller can persist the cooldown
///   (`AppVersionGateController.recordSoftPromptDismissed`).
///
/// [launchStore] is the injected store-launch seam (no `url_launcher`
/// dependency baked in here) — a `false`/thrown result shows an inline
/// error and a "Retry" button instead of silently retrying in a loop.
class AppVersionGateOverlay extends StatefulWidget {
  const AppVersionGateOverlay({
    super.key,
    required this.child,
    required this.decision,
    required this.config,
    required this.launchStore,
    this.onSoftDismiss,
    this.labels = const AppVersionGateLabels(),
  });

  final Widget child;
  final GateDecision decision;
  final AppVersionGateConfig config;
  final Future<bool> Function(String url) launchStore;
  final VoidCallback? onSoftDismiss;

  /// Every user-visible text of the overlay; the defaults are the current
  /// (mixed Vietnamese / English) strings, kept unchanged.
  final AppVersionGateLabels labels;

  @override
  State<AppVersionGateOverlay> createState() => _AppVersionGateOverlayState();
}

class _AppVersionGateOverlayState extends State<AppVersionGateOverlay> {
  bool _dismissed = false;
  bool _launching = false;
  bool _launchFailed = false;

  @override
  void didUpdateWidget(covariant AppVersionGateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decision != widget.decision) {
      _dismissed = false;
      _launchFailed = false;
    }
  }

  bool get _blocking =>
      widget.decision == GateDecision.maintenance ||
      widget.decision == GateDecision.forceUpdate;

  Future<void> _launch() async {
    setState(() {
      _launching = true;
      _launchFailed = false;
    });
    bool ok;
    try {
      ok = await widget.launchStore(widget.config.storeUrl ?? '');
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _launching = false;
      _launchFailed = !ok;
    });
  }

  void _dismissSoft() {
    setState(() => _dismissed = true);
    widget.onSoftDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = widget.decision != GateDecision.ok && !_dismissed;
    return PopScope(
      key: const Key('appVersionGatePopScope'),
      canPop: !showOverlay || !_blocking,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _blocking) return;
        _dismissSoft();
      },
      child: Stack(
        children: [widget.child, if (showOverlay) _buildOverlay(context)],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final isMaintenance = widget.decision == GateDecision.maintenance;
    final labels = widget.labels;
    final title = isMaintenance
        ? labels.maintenanceTitle
        : _blocking
        ? labels.requiredTitle
        : labels.optionalTitle;
    final message = isMaintenance
        ? (widget.config.maintenanceMessage ?? labels.maintenanceMessage)
        : labels.updateMessage;

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: PanelCard(
          child: Padding(
            padding: const EdgeInsets.all(NeonTheme.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
                Text(message),
                if (_launchFailed) ...[
                  const SizedBox(height: NeonTheme.s8),
                  Text(
                    labels.storeOpenFailed,
                    style: TextStyle(color: NeonTheme.red),
                  ),
                ],
                const SizedBox(height: NeonTheme.s16),
                Wrap(
                  spacing: NeonTheme.s8,
                  children: [
                    if (!isMaintenance)
                      CommonButton(
                        label: _launchFailed
                            ? labels.retry
                            : (_launching ? labels.opening : labels.updateNow),
                        onTap: _launching ? null : _launch,
                      ),
                    if (!_blocking)
                      CommonButton(
                        label: labels.later,
                        variant: CommonButtonVariant.secondary,
                        onTap: _dismissSoft,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Texts shown by [AppVersionGateOverlay]. The defaults are the strings the
/// overlay always used, so passing nothing changes nothing.
class AppVersionGateLabels {
  const AppVersionGateLabels({
    this.maintenanceTitle = 'Đang bảo trì',
    this.requiredTitle = 'Cần cập nhật',
    this.optionalTitle = 'Có bản cập nhật mới',
    this.maintenanceMessage = 'App đang bảo trì, vui lòng quay lại sau.',
    this.updateMessage =
        'Vui lòng cập nhật lên phiên bản mới nhất để tiếp tục.',
    this.storeOpenFailed = 'Không thể mở cửa hàng ứng dụng.',
    this.updateNow = 'Update now',
    this.opening = 'Đang mở…',
    this.retry = 'Retry',
    this.later = 'Để sau',
  });

  final String maintenanceTitle;
  final String requiredTitle;
  final String optionalTitle;
  final String maintenanceMessage;
  final String updateMessage;
  final String storeOpenFailed;
  final String updateNow;
  final String opening;
  final String retry;
  final String later;
}
