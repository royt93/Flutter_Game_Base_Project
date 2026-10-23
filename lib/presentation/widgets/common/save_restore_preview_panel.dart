import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class RestoreSlotPreview {
  RestoreSlotPreview({
    required this.slotName,
    required this.lastPlayedText,
    required this.keyCount,
  }) {
    for (final (name, value) in [
      ('slotName', slotName),
      ('lastPlayedText', lastPlayedText),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (keyCount < 0) {
      throw ArgumentError.value(keyCount, 'keyCount', 'must be >= 0');
    }
  }

  final String slotName;
  final String lastPlayedText;
  final int keyCount;
}

/// Per-slot summary shown before a destructive restore. The caller maps a
/// validated `RestorePreview` to [slots] and runs `applyRestore` itself in
/// [onConfirmRestore]. The widget never receives slot data, the signed bundle,
/// the secret or the recovery-log detail, and never renders a slot id.
/// Restoring needs an explicit inline confirmation.
class SaveRestorePreviewPanel extends StatefulWidget {
  SaveRestorePreviewPanel({
    super.key,
    required List<RestoreSlotPreview> slots,
    required this.onConfirmRestore,
    this.appVersionText,
    this.generatedAtText,
    this.busy = false,
    this.title = 'Restore preview',
    this.emptyLabel = 'This backup contains no save slots.',
    this.appVersionLabel = 'App version',
    this.generatedLabel = 'Backup created',
    this.keysLabel = 'saved values',
    this.restoreLabel = 'Restore these slots',
    this.confirmationText =
        'This replaces matching slots on this device and cannot be undone.',
    this.confirmLabel = 'Confirm restore',
    this.cancelLabel = 'Cancel',
    this.errorLabel = 'Restore failed. Try again.',
  }) : slots = List.unmodifiable(slots) {
    for (final (name, value) in [
      ('appVersionText', appVersionText),
      ('generatedAtText', generatedAtText),
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('appVersionLabel', appVersionLabel),
      ('generatedLabel', generatedLabel),
      ('keysLabel', keysLabel),
      ('restoreLabel', restoreLabel),
      ('confirmationText', confirmationText),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<RestoreSlotPreview> slots;
  final Future<void> Function() onConfirmRestore;
  final String? appVersionText;
  final String? generatedAtText;
  final bool busy;
  final String title;
  final String emptyLabel;
  final String appVersionLabel;
  final String generatedLabel;
  final String keysLabel;
  final String restoreLabel;
  final String confirmationText;
  final String confirmLabel;
  final String cancelLabel;
  final String errorLabel;

  @override
  State<SaveRestorePreviewPanel> createState() =>
      _SaveRestorePreviewPanelState();
}

class _SaveRestorePreviewPanelState extends State<SaveRestorePreviewPanel> {
  bool _confirming = false;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant SaveRestorePreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy || _slotsChanged(oldWidget.slots)) {
      _generation++;
      _confirming = false;
      _failed = false;
    }
  }

  bool _slotsChanged(List<RestoreSlotPreview> old) {
    if (old.length != widget.slots.length) return true;
    for (var i = 0; i < old.length; i++) {
      final a = old[i];
      final b = widget.slots[i];
      if (a.slotName != b.slotName ||
          a.lastPlayedText != b.lastPlayedText ||
          a.keyCount != b.keyCount) {
        return true;
      }
    }
    return false;
  }

  Future<void> _restore() async {
    if (_isBusy || widget.slots.isEmpty) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onConfirmRestore();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (generation == _generation) {
        _confirming = false;
        _failed = failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
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
            if (widget.appVersionText != null)
              Text('${widget.appVersionLabel}: ${widget.appVersionText}'),
            if (widget.generatedAtText != null)
              Text('${widget.generatedLabel}: ${widget.generatedAtText}'),
            if (widget.slots.isEmpty) Text(widget.emptyLabel),
            for (final slot in widget.slots) ...[
              const SizedBox(height: 8),
              Text(slot.slotName, style: TextStyle(color: NeonTheme.ink)),
              Text(
                '${slot.lastPlayedText} · ${slot.keyCount} ${widget.keysLabel}',
              ),
            ],
            if (_failed)
              Semantics(liveRegion: true, child: Text(widget.errorLabel)),
            if (widget.slots.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_confirming) ...[
                Text(widget.confirmationText),
                CommonButton(
                  key: const ValueKey('restorePreviewConfirm'),
                  label: widget.confirmLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  loading: _running,
                  onTap: _isBusy ? null : _restore,
                ),
                const SizedBox(height: 8),
                CommonButton(
                  key: const ValueKey('restorePreviewCancel'),
                  label: widget.cancelLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => setState(() => _confirming = false),
                ),
              ] else
                CommonButton(
                  key: const ValueKey('restorePreviewStart'),
                  label: widget.restoreLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => setState(() {
                          _confirming = true;
                          _failed = false;
                        }),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
