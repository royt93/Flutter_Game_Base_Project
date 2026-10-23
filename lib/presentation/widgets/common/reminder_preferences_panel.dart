import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class ReminderIntervalOption {
  ReminderIntervalOption({required this.id, required this.label}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
  }

  /// Opaque caller reference. Never rendered.
  final String id;
  final String label;
}

/// Caller-owned reminder preference control. Callback completion means the
/// caller accepted the request, not that the OS scheduled or will deliver it.
/// The platform may delay delivery or suppress it when notification permission
/// is unavailable.
class ReminderPreferencesPanel extends StatefulWidget {
  ReminderPreferencesPanel({
    super.key,
    required List<ReminderIntervalOption> intervalOptions,
    required this.enabled,
    required this.selectedId,
    required this.onChanged,
    this.busy = false,
    this.title = 'Reminder preferences',
    this.enabledLabel = 'Reminders enabled',
    this.disabledLabel = 'Reminders disabled',
    this.permissionNote =
        'Delivery depends on notification permission. The system may delay or skip reminders.',
    this.saveLabel = 'Save reminder preference',
    this.errorLabel = 'Could not save preference. Try again.',
  }) : intervalOptions = List.unmodifiable(intervalOptions) {
    if (intervalOptions.isEmpty) {
      throw ArgumentError.value(
        intervalOptions,
        'intervalOptions',
        'must not be empty',
      );
    }
    final ids = <String>{};
    for (final option in intervalOptions) {
      if (!ids.add(option.id)) {
        throw ArgumentError.value(option.id, 'intervalOptions', 'duplicate id');
      }
    }
    if (selectedId != null && !ids.contains(selectedId)) {
      throw ArgumentError.value(
        selectedId,
        'selectedId',
        'must match an interval option',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('enabledLabel', enabledLabel),
      ('disabledLabel', disabledLabel),
      ('permissionNote', permissionNote),
      ('saveLabel', saveLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<ReminderIntervalOption> intervalOptions;
  final bool enabled;
  final String? selectedId;
  final Future<void> Function(bool enabled, String? selectedId) onChanged;
  final bool busy;
  final String title;
  final String enabledLabel;
  final String disabledLabel;
  final String permissionNote;
  final String saveLabel;
  final String errorLabel;

  @override
  State<ReminderPreferencesPanel> createState() =>
      _ReminderPreferencesPanelState();
}

class _ReminderPreferencesPanelState extends State<ReminderPreferencesPanel> {
  bool _enabled = false;
  String? _selectedId;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant ReminderPreferencesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.busy != widget.busy) {
      _generation++;
      _syncFromWidget();
      _failed = false;
    }
  }

  void _syncFromWidget() {
    _enabled = widget.enabled;
    _selectedId = widget.selectedId;
  }

  Future<void> _save() async {
    if (_isBusy) return;
    final generation = _generation;
    final enabled = _enabled;
    final selectedId = _selectedId;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onChanged(enabled, selectedId);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (generation == _generation) _failed = failed;
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
            SwitchListTile(
              key: const ValueKey('reminderEnabled'),
              title: Text(
                _enabled ? widget.enabledLabel : widget.disabledLabel,
              ),
              value: _enabled,
              onChanged: _isBusy
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            RadioGroup<String>(
              groupValue: _selectedId,
              onChanged: (value) {
                if (_enabled && !_isBusy) setState(() => _selectedId = value);
              },
              child: Column(
                children: [
                  for (final option in widget.intervalOptions)
                    RadioListTile<String>(
                      key: ValueKey('reminderInterval_${option.id}'),
                      title: Text(option.label),
                      value: option.id,
                      enabled: _enabled && !_isBusy,
                    ),
                ],
              ),
            ),
            Text(widget.permissionNote),
            if (_failed) Text(widget.errorLabel),
            const SizedBox(height: 8),
            CommonButton(
              key: const ValueKey('reminderPreferencesSave'),
              label: widget.saveLabel,
              width: double.infinity,
              loading: _running,
              onTap: _isBusy ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
