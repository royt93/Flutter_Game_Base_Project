import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class ExperimentVariantRow {
  ExperimentVariantRow({
    required this.experimentKey,
    required this.label,
    required this.assignedVariant,
    required List<String> availableVariants,
    this.isOverridden = false,
  }) : availableVariants = List.unmodifiable(availableVariants) {
    if (experimentKey.trim().isEmpty) {
      throw ArgumentError.value(
        experimentKey,
        'experimentKey',
        'must not be blank',
      );
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (this.availableVariants.isEmpty) {
      throw ArgumentError.value(
        availableVariants,
        'availableVariants',
        'must not be empty',
      );
    }
    if (this.availableVariants.any((v) => v.trim().isEmpty) ||
        this.availableVariants.toSet().length !=
            this.availableVariants.length) {
      throw ArgumentError.value(
        availableVariants,
        'availableVariants',
        'must be nonblank and unique',
      );
    }
    if (!this.availableVariants.contains(assignedVariant)) {
      throw ArgumentError.value(
        assignedVariant,
        'assignedVariant',
        'must be one of availableVariants',
      );
    }
  }

  /// Only identifies the row in callbacks; never rendered.
  final String experimentKey;
  final String label;
  final String assignedVariant;
  final List<String> availableVariants;
  final bool isOverridden;
}

/// Read-only experiment assignments. The caller maps `variantFor` results to
/// rows; the per-device anonymous id never enters or leaves this widget. The
/// override controls only appear in debug or profile builds, matching
/// `ExperimentBucketingService.debugSetVariantOverride`, which is a no-op in
/// release; in release the card stays read-only even if `onSelectOverride`
/// is passed.
class ExperimentVariantAssignmentCard extends StatefulWidget {
  ExperimentVariantAssignmentCard({
    super.key,
    required List<ExperimentVariantRow> rows,
    this.onSelectOverride,
    this.busy = false,
    this.title = 'Experiment assignments',
    this.emptyLabel = 'No experiments registered.',
    this.assignedLabel = 'Assigned variant',
    this.overriddenLabel = 'Overridden for testing',
    this.clearOverrideLabel = 'Clear override',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) : rows = List.unmodifiable(rows) {
    if (this.rows.map((r) => r.experimentKey).toSet().length !=
        this.rows.length) {
      throw ArgumentError.value(
        rows,
        'rows',
        'experimentKey values must be unique',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('assignedLabel', assignedLabel),
      ('overriddenLabel', overriddenLabel),
      ('clearOverrideLabel', clearOverrideLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<ExperimentVariantRow> rows;

  static const bool _overrideAllowed = kDebugMode || kProfileMode;

  /// `variant == null` clears the override.
  final Future<void> Function(String experimentKey, String? variant)?
  onSelectOverride;
  final bool busy;
  final String title;
  final String emptyLabel;
  final String assignedLabel;
  final String overriddenLabel;
  final String clearOverrideLabel;
  final String actionErrorLabel;

  @override
  State<ExperimentVariantAssignmentCard> createState() =>
      _ExperimentVariantAssignmentCardState();
}

class _ExperimentVariantAssignmentCardState
    extends State<ExperimentVariantAssignmentCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant ExperimentVariantAssignmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        !_sameRows(oldWidget.rows, widget.rows)) {
      _generation++;
      _failed = false;
    }
  }

  bool _sameRows(List<ExperimentVariantRow> a, List<ExperimentVariantRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].experimentKey != b[i].experimentKey ||
          a[i].label != b[i].label ||
          a[i].assignedVariant != b[i].assignedVariant ||
          a[i].isOverridden != b[i].isOverridden ||
          a[i].availableVariants.join('\u0000') !=
              b[i].availableVariants.join('\u0000')) {
        return false;
      }
    }
    return true;
  }

  Future<void> _select(String key, String? variant) async {
    final action = widget.onSelectOverride;
    if (_isBusy ||
        action == null ||
        !ExperimentVariantAssignmentCard._overrideAllowed) {
      return;
    }
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await action(key, variant);
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: NeonTheme.ink, fontSize: 18),
            ),
            if (widget.rows.isEmpty) Text(widget.emptyLabel),
            for (final row in widget.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${widget.assignedLabel}: ${row.assignedVariant}',
                      ),
                    ),
                    if (row.isOverridden) Text(widget.overriddenLabel),
                    if (widget.onSelectOverride != null &&
                        ExperimentVariantAssignmentCard._overrideAllowed) ...[
                      for (final variant in row.availableVariants)
                        if (variant != row.assignedVariant || !row.isOverridden)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: CommonButton(
                              key: ValueKey(
                                'experimentOverride_${row.experimentKey}_$variant',
                              ),
                              label: variant,
                              variant: CommonButtonVariant.secondary,
                              width: double.infinity,
                              onTap: _isBusy || variant == row.assignedVariant
                                  ? null
                                  : () => _select(row.experimentKey, variant),
                            ),
                          ),
                      if (row.isOverridden)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: CommonButton(
                            key: ValueKey(
                              'experimentClear_${row.experimentKey}',
                            ),
                            label: widget.clearOverrideLabel,
                            width: double.infinity,
                            loading: _running,
                            onTap: _isBusy
                                ? null
                                : () => _select(row.experimentKey, null),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            if (_failed) Text(widget.actionErrorLabel),
          ],
        ),
      ),
    ),
  );
}
