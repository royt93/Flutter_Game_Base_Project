import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum _RightsStatus { none, exported, erased, failed }

/// Presentation-only export/erase panel for `PlayerDataRightsService`.
///
/// The caller runs the service and inspects its receipt; this widget never
/// receives or renders it. Callback completion without a throw is shown as
/// success, so a caller must throw when the requested work did not finish.
/// Erase requires inline confirmation.
class PlayerDataRightsPanel extends StatefulWidget {
  PlayerDataRightsPanel({
    super.key,
    required this.onExport,
    required this.onErase,
    this.busy = false,
    this.title = 'Your data',
    this.description =
        'Export a copy of your data or erase it from this device.',
    this.exportLabel = 'Export my data',
    this.eraseLabel = 'Erase my data',
    this.confirmEraseLabel = 'Confirm erase',
    this.cancelLabel = 'Cancel',
    this.erasureWarning =
        'This permanently erases your data on this device and cannot be undone.',
    this.exportSuccessLabel = 'Your data export is ready.',
    this.eraseSuccessLabel = 'Your device data was erased.',
    this.errorLabel = 'Something went wrong. Please try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('description', description),
      ('exportLabel', exportLabel),
      ('eraseLabel', eraseLabel),
      ('confirmEraseLabel', confirmEraseLabel),
      ('cancelLabel', cancelLabel),
      ('erasureWarning', erasureWarning),
      ('exportSuccessLabel', exportSuccessLabel),
      ('eraseSuccessLabel', eraseSuccessLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final Future<void> Function() onExport;
  final Future<void> Function() onErase;
  final bool busy;
  final String title;
  final String description;
  final String exportLabel;
  final String eraseLabel;
  final String confirmEraseLabel;
  final String cancelLabel;
  final String erasureWarning;
  final String exportSuccessLabel;
  final String eraseSuccessLabel;
  final String errorLabel;

  @override
  State<PlayerDataRightsPanel> createState() => _PlayerDataRightsPanelState();
}

class _PlayerDataRightsPanelState extends State<PlayerDataRightsPanel> {
  bool _confirmingErase = false;
  bool _running = false;
  _RightsStatus _status = _RightsStatus.none;
  int _generation = 0;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant PlayerDataRightsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) {
      _generation++;
      _confirmingErase = false;
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    _RightsStatus success,
  ) async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _confirmingErase = false;
      _status = _RightsStatus.none;
    });
    var failed = false;
    try {
      await action();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (_generation == generation) {
        _status = failed ? _RightsStatus.failed : success;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_status) {
      _RightsStatus.none => null,
      _RightsStatus.exported => widget.exportSuccessLabel,
      _RightsStatus.erased => widget.eraseSuccessLabel,
      _RightsStatus.failed => widget.errorLabel,
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: TextStyle(color: NeonTheme.ink, fontSize: 18),
              ),
              Text(widget.description),
              if (status != null)
                Semantics(liveRegion: true, child: Text(status)),
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('dataRightsExport'),
                label: widget.exportLabel,
                variant: CommonButtonVariant.secondary,
                width: double.infinity,
                onTap: _busy
                    ? null
                    : () => _run(widget.onExport, _RightsStatus.exported),
              ),
              const SizedBox(height: 8),
              if (_confirmingErase) ...[
                Text(widget.erasureWarning),
                CommonButton(
                  key: const ValueKey('dataRightsEraseConfirm'),
                  label: widget.confirmEraseLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _busy
                      ? null
                      : () => _run(widget.onErase, _RightsStatus.erased),
                ),
                const SizedBox(height: 8),
                CommonButton(
                  key: const ValueKey('dataRightsEraseCancel'),
                  label: widget.cancelLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _busy
                      ? null
                      : () => setState(() => _confirmingErase = false),
                ),
              ] else
                CommonButton(
                  key: const ValueKey('dataRightsErase'),
                  label: widget.eraseLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _confirmingErase = true;
                          _status = _RightsStatus.none;
                        }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
