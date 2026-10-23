import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'panel_card.dart';

enum GuardrailRowState { noData, ok, violated }

@immutable
class GuardrailStatusRow {
  GuardrailStatusRow({
    required this.featureLabel,
    required this.metricLabel,
    required this.state,
    this.boundsText,
    this.currentText,
  }) {
    for (final (name, value) in [
      ('featureLabel', featureLabel),
      ('metricLabel', metricLabel),
      ('boundsText', boundsText),
      ('currentText', currentText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String featureLabel;
  final String metricLabel;
  final GuardrailRowState state;

  /// Optional caller-formatted bounds; omit to keep internal thresholds hidden.
  final String? boundsText;

  /// Optional caller-formatted reading; omit to keep internal metrics hidden.
  final String? currentText;
}

/// Read-only guardrail status. `ShadowActivationController` exposes no read
/// API, so the caller supplies rows from its own definitions and readings.
class GuardrailStatusPanel extends StatelessWidget {
  GuardrailStatusPanel({
    super.key,
    required List<GuardrailStatusRow> rows,
    this.title = 'Rollout guardrails',
    this.emptyLabel = 'No guardrails registered.',
    this.noDataLabel = 'No data yet',
    this.okLabel = 'Within limits',
    this.violatedLabel = 'Rolled back on this device',
    this.boundsLabel = 'Limits',
    this.currentLabel = 'Current',
  }) : rows = List.unmodifiable(rows) {
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('noDataLabel', noDataLabel),
      ('okLabel', okLabel),
      ('violatedLabel', violatedLabel),
      ('boundsLabel', boundsLabel),
      ('currentLabel', currentLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<GuardrailStatusRow> rows;
  final String title;
  final String emptyLabel;
  final String noDataLabel;
  final String okLabel;
  final String violatedLabel;
  final String boundsLabel;
  final String currentLabel;

  String _stateLabel(GuardrailRowState state) => switch (state) {
    GuardrailRowState.noData => noDataLabel,
    GuardrailRowState.ok => okLabel,
    GuardrailRowState.violated => violatedLabel,
  };

  IconData _icon(GuardrailRowState state) => switch (state) {
    GuardrailRowState.noData => Icons.hourglass_empty,
    GuardrailRowState.ok => Icons.check_circle_outline,
    GuardrailRowState.violated => Icons.warning_amber_outlined,
  };

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
            Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
            if (rows.isEmpty) Text(emptyLabel),
            for (final row in rows) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(row.state), color: NeonTheme.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.featureLabel,
                          style: TextStyle(color: NeonTheme.ink),
                        ),
                        Text('${row.metricLabel}: ${_stateLabel(row.state)}'),
                        if (row.boundsText != null)
                          Text('$boundsLabel: ${row.boundsText}'),
                        if (row.currentText != null)
                          Text('$currentLabel: ${row.currentText}'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
