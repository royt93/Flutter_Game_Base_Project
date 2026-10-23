import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class KillSwitchItem {
  KillSwitchItem({
    required this.id,
    required this.label,
    required this.killed,
    required this.sourceLabel,
    this.reasonText,
    this.localOverride = false,
  }) {
    for (final (name, value) in [
      ('id', id),
      ('label', label),
      ('sourceLabel', sourceLabel),
      ('reasonText', reasonText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    if (localOverride && !killed) {
      throw ArgumentError.value(
        localOverride,
        'localOverride',
        'requires killed state',
      );
    }
  }

  /// Opaque caller reference; never rendered.
  final String id;
  final String label;
  final bool killed;
  final String sourceLabel;
  final String? reasonText;
  final bool localOverride;
}

/// Safe local-control panel for kill-switch state. The caller maps service
/// state to [KillSwitchItem], sanitizing any remote reason before passing it.
/// This widget cannot enable a remotely killed feature; it only offers a
/// confirmed client-local kill and a clear action for an existing local
/// override.
class RemoteKillSwitchPanel extends StatefulWidget {
  RemoteKillSwitchPanel({
    super.key,
    required List<KillSwitchItem> items,
    required this.onKillLocally,
    required this.onClearOverride,
    this.busy = false,
    this.title = 'Feature safety switches',
    this.killedLabel = 'Killed',
    this.activeLabel = 'Active',
    this.killLabel = 'Kill locally',
    this.confirmKillLabel = 'Confirm local kill',
    this.clearLabel = 'Clear local override',
    this.confirmationText =
        'This only kills the feature on this device. It cannot enable a remotely killed feature.',
    this.cancelLabel = 'Cancel',
    this.errorLabel = 'Could not apply this change. Please try again.',
    this.emptyLabel = 'No feature switches.',
  }) : items = List.unmodifiable(items) {
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'items', 'duplicate id');
      }
    }
    for (final (name, value) in [
      ('title', title),
      ('killedLabel', killedLabel),
      ('activeLabel', activeLabel),
      ('killLabel', killLabel),
      ('confirmKillLabel', confirmKillLabel),
      ('clearLabel', clearLabel),
      ('confirmationText', confirmationText),
      ('cancelLabel', cancelLabel),
      ('errorLabel', errorLabel),
      ('emptyLabel', emptyLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<KillSwitchItem> items;
  final Future<void> Function(String id) onKillLocally;
  final Future<void> Function(String id) onClearOverride;
  final bool busy;
  final String title;
  final String killedLabel;
  final String activeLabel;
  final String killLabel;
  final String confirmKillLabel;
  final String clearLabel;
  final String confirmationText;
  final String cancelLabel;
  final String errorLabel;
  final String emptyLabel;

  @override
  State<RemoteKillSwitchPanel> createState() => _RemoteKillSwitchPanelState();
}

class _RemoteKillSwitchPanelState extends State<RemoteKillSwitchPanel> {
  String? _selectedId;
  String? _failedId;
  bool _running = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant RemoteKillSwitchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy || _changedItems(oldWidget.items)) {
      _generation++;
      _selectedId = null;
      _failedId = null;
    }
  }

  bool _changedItems(List<KillSwitchItem> oldItems) {
    if (oldItems.length != widget.items.length) return true;
    for (var i = 0; i < oldItems.length; i++) {
      final a = oldItems[i];
      final b = widget.items[i];
      if (a.id != b.id ||
          a.label != b.label ||
          a.killed != b.killed ||
          a.sourceLabel != b.sourceLabel ||
          a.reasonText != b.reasonText ||
          a.localOverride != b.localOverride) {
        return true;
      }
    }
    return false;
  }

  Future<void> _run(String id, Future<void> Function(String) action) async {
    if (_isBusy) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failedId = null;
    });
    var failed = false;
    try {
      await action(id);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (generation == _generation) {
        _selectedId = null;
        if (failed) _failedId = id;
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
            if (widget.items.isEmpty) Text(widget.emptyLabel),
            for (final item in widget.items) ...[
              const SizedBox(height: 12),
              Text(item.label, style: TextStyle(color: NeonTheme.ink)),
              Text(item.killed ? widget.killedLabel : widget.activeLabel),
              Text(item.sourceLabel),
              if (item.reasonText != null) Text(item.reasonText!),
              if (_failedId == item.id)
                Semantics(liveRegion: true, child: Text(widget.errorLabel)),
              if (_selectedId == item.id && !item.killed) ...[
                Text(widget.confirmationText),
                CommonButton(
                  key: ValueKey('killSwitchConfirm_${item.id}'),
                  label: widget.confirmKillLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => _run(item.id, widget.onKillLocally),
                ),
                const SizedBox(height: 8),
                CommonButton(
                  key: ValueKey('killSwitchCancel_${item.id}'),
                  label: widget.cancelLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => setState(() => _selectedId = null),
                ),
              ] else if (item.localOverride)
                CommonButton(
                  key: ValueKey('killSwitchClear_${item.id}'),
                  label: widget.clearLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => _run(item.id, widget.onClearOverride),
                )
              else if (!item.killed)
                CommonButton(
                  key: ValueKey('killSwitchSelect_${item.id}'),
                  label: widget.killLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _isBusy
                      ? null
                      : () => setState(() {
                          _selectedId = item.id;
                          _failedId = null;
                        }),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
