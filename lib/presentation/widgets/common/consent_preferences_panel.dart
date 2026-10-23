import 'package:flutter/material.dart';

import '../../../core/consent_state_service.dart' show ConsentStatus;
import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class ConsentPreferenceItem {
  ConsentPreferenceItem({
    required this.id,
    required this.label,
    required this.description,
    required this.status,
  }) {
    for (final (name, value) in [
      ('id', id),
      ('label', label),
      ('description', description),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  /// Opaque caller reference passed back to `onChanged`.
  final String id;
  final String label;
  final String description;
  final ConsentStatus status;
}

/// Presentation-only, ongoing consent preferences (the first-run prompt is
/// `ConsentBanner`). Allow and Don't allow have equal visual weight; the
/// button matching the current choice is disabled. The caller applies the
/// change (for example `ConsentStateService.grant`/`deny`). A callback that
/// returns without throwing is shown as saved, so throw when it did not apply.
class ConsentPreferencesPanel extends StatefulWidget {
  ConsentPreferencesPanel({
    super.key,
    required List<ConsentPreferenceItem> items,
    required this.onChanged,
    this.busy = false,
    this.title = 'Privacy choices',
    this.allowLabel = 'Allow',
    this.denyLabel = "Don't allow",
    this.grantedLabel = 'Allowed',
    this.deniedLabel = 'Not allowed',
    this.unknownLabel = 'Not decided yet',
    this.errorLabel = 'Could not save your choice. Please try again.',
  }) : items = List.unmodifiable(items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'items', 'duplicate id');
      }
    }
    for (final (name, value) in [
      ('title', title),
      ('allowLabel', allowLabel),
      ('denyLabel', denyLabel),
      ('grantedLabel', grantedLabel),
      ('deniedLabel', deniedLabel),
      ('unknownLabel', unknownLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<ConsentPreferenceItem> items;

  /// Called with the item id and [ConsentStatus.granted] or
  /// [ConsentStatus.denied].
  final Future<void> Function(String id, ConsentStatus status) onChanged;
  final bool busy;
  final String title;
  final String allowLabel;
  final String denyLabel;
  final String grantedLabel;
  final String deniedLabel;
  final String unknownLabel;
  final String errorLabel;

  @override
  State<ConsentPreferencesPanel> createState() =>
      _ConsentPreferencesPanelState();
}

class _ConsentPreferencesPanelState extends State<ConsentPreferencesPanel> {
  bool _running = false;
  String? _failedId;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant ConsentPreferencesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy || _itemsChanged(oldWidget)) {
      _failedId = null;
    }
  }

  bool _itemsChanged(ConsentPreferencesPanel old) {
    if (old.items.length != widget.items.length) return true;
    for (var i = 0; i < old.items.length; i++) {
      final a = old.items[i];
      final b = widget.items[i];
      if (a.id != b.id ||
          a.label != b.label ||
          a.description != b.description ||
          a.status != b.status) {
        return true;
      }
    }
    return false;
  }

  Future<void> _change(String id, ConsentStatus status) async {
    if (_busy) return;
    setState(() {
      _running = true;
      _failedId = null;
    });
    var failed = false;
    try {
      await widget.onChanged(id, status);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (failed) _failedId = id;
    });
  }

  String _statusText(ConsentStatus status) => switch (status) {
    ConsentStatus.granted => widget.grantedLabel,
    ConsentStatus.denied => widget.deniedLabel,
    ConsentStatus.unknown => widget.unknownLabel,
  };

  @override
  Widget build(BuildContext context) {
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
              for (final item in widget.items) ...[
                const SizedBox(height: 12),
                Text(item.label, style: TextStyle(color: NeonTheme.ink)),
                Text(item.description),
                Text(_statusText(item.status)),
                if (_failedId == item.id)
                  Semantics(liveRegion: true, child: Text(widget.errorLabel)),
                const SizedBox(height: 8),
                CommonButton(
                  key: ValueKey('consentAllow_${item.id}'),
                  label: widget.allowLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _busy || item.status == ConsentStatus.granted
                      ? null
                      : () => _change(item.id, ConsentStatus.granted),
                ),
                const SizedBox(height: 8),
                CommonButton(
                  key: ValueKey('consentDeny_${item.id}'),
                  label: widget.denyLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _busy || item.status == ConsentStatus.denied
                      ? null
                      : () => _change(item.id, ConsentStatus.denied),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
