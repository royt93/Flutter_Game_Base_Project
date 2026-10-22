import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class ContentRevisionSummary {
  ContentRevisionSummary({
    required this.revision,
    required this.version,
    required this.appliedAtText,
    required this.label,
  }) {
    if (revision.trim().isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be blank');
    }
    if (version < 0) {
      throw ArgumentError.value(version, 'version', 'must be >= 0');
    }
    for (final (name, value) in [
      ('appliedAtText', appliedAtText),
      ('label', label),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  /// Opaque stable reference, not a checksum or content identifier.
  final String revision;
  final int version;
  final String appliedAtText;
  final String label;
}

class ContentRevisionHistoryPanel extends StatefulWidget {
  ContentRevisionHistoryPanel({
    super.key,
    required List<ContentRevisionSummary> revisions,
    required this.currentRevision,
    required this.onRollback,
    this.busy = false,
    this.title = 'Content revision history',
    this.currentLabel = 'Active',
    this.rollbackLabel = 'Restore this revision',
    this.confirmLabel = 'Confirm restore',
    this.cancelLabel = 'Cancel',
    this.confirmationText =
        'This changes the active content and may require the app to refresh it.',
    this.errorLabel = 'Could not restore this revision. Select again to retry.',
    this.emptyLabel = 'No previous content revisions.',
  }) : revisions = List.unmodifiable(revisions) {
    for (final (name, value) in [
      ('title', title),
      ('currentLabel', currentLabel),
      ('rollbackLabel', rollbackLabel),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('confirmationText', confirmationText),
      ('errorLabel', errorLabel),
      ('emptyLabel', emptyLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    final refs = <String>{};
    for (final revision in revisions) {
      if (!refs.add(revision.revision)) {
        throw ArgumentError.value(
          revisions,
          'revisions',
          'duplicate opaque revision reference',
        );
      }
    }
    if (currentRevision != null && !refs.contains(currentRevision)) {
      throw ArgumentError.value(
        currentRevision,
        'currentRevision',
        'must match a revision entry',
      );
    }
  }

  final List<ContentRevisionSummary> revisions;
  final String? currentRevision;
  final Future<void> Function(String revision) onRollback;
  final bool busy;
  final String title;
  final String currentLabel;
  final String rollbackLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String confirmationText;
  final String errorLabel;
  final String emptyLabel;

  @override
  State<ContentRevisionHistoryPanel> createState() =>
      _ContentRevisionHistoryPanelState();
}

class _ContentRevisionHistoryPanelState
    extends State<ContentRevisionHistoryPanel> {
  String? _selectedRevision;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant ContentRevisionHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEntries = oldWidget.revisions
        .map(
          (entry) =>
              (entry.revision, entry.version, entry.appliedAtText, entry.label),
        )
        .toSet();
    final entries = widget.revisions
        .map(
          (entry) =>
              (entry.revision, entry.version, entry.appliedAtText, entry.label),
        )
        .toSet();
    if (!oldEntries.containsAll(entries) ||
        !entries.containsAll(oldEntries) ||
        widget.currentRevision != oldWidget.currentRevision ||
        widget.busy != oldWidget.busy) {
      _generation++;
      _selectedRevision = null;
      _failed = false;
    }
  }

  Future<void> _rollback() async {
    final revision = _selectedRevision;
    if (_busy || revision == null || revision == widget.currentRevision) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onRollback(revision);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (_generation == generation) {
        _selectedRevision = null;
        _failed = failed;
      }
    });
  }

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
              if (_failed) Text(widget.errorLabel),
              if (widget.revisions.isEmpty)
                Text(widget.emptyLabel)
              else
                for (final revision in widget.revisions)
                  _ContentRevisionRow(
                    key: ValueKey('contentRevision_${revision.revision}'),
                    revision: revision,
                    current: revision.revision == widget.currentRevision,
                    selected: revision.revision == _selectedRevision,
                    busy: _busy,
                    currentLabel: widget.currentLabel,
                    rollbackLabel: widget.rollbackLabel,
                    confirmLabel: widget.confirmLabel,
                    cancelLabel: widget.cancelLabel,
                    confirmationText: widget.confirmationText,
                    onSelect: () => setState(() {
                      _selectedRevision = revision.revision;
                      _failed = false;
                    }),
                    onConfirm: _rollback,
                    onCancel: () => setState(() {
                      _selectedRevision = null;
                      _failed = false;
                    }),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentRevisionRow extends StatelessWidget {
  const _ContentRevisionRow({
    required this.revision,
    required this.current,
    required this.selected,
    required this.busy,
    required this.currentLabel,
    required this.rollbackLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmationText,
    required this.onSelect,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final ContentRevisionSummary revision;
  final bool current;
  final bool selected;
  final bool busy;
  final String currentLabel;
  final String rollbackLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String confirmationText;
  final VoidCallback onSelect;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Version ${revision.version}: ${revision.label}'),
        Text(revision.appliedAtText),
        if (current)
          Text(currentLabel)
        else if (selected) ...[
          Text(confirmationText),
          CommonButton(
            key: ValueKey('contentRevisionConfirm_${revision.revision}'),
            label: confirmLabel,
            variant: CommonButtonVariant.danger,
            width: double.infinity,
            onTap: busy ? null : onConfirm,
          ),
          const SizedBox(height: 8),
          CommonButton(
            key: ValueKey('contentRevisionCancel_${revision.revision}'),
            label: cancelLabel,
            variant: CommonButtonVariant.secondary,
            width: double.infinity,
            onTap: busy ? null : onCancel,
          ),
        ] else
          CommonButton(
            key: ValueKey('contentRevisionSelect_${revision.revision}'),
            label: rollbackLabel,
            variant: CommonButtonVariant.secondary,
            width: double.infinity,
            onTap: busy ? null : onSelect,
          ),
      ],
    ),
  );
}
