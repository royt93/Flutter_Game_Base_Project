import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'panel_card.dart';

@immutable
class EventSchemaAuditSnapshot {
  EventSchemaAuditSnapshot({
    required this.totalValidations,
    required this.rejectedCount,
    required this.redactedCount,
  }) {
    for (final (name, value) in [
      ('totalValidations', totalValidations),
      ('rejectedCount', rejectedCount),
      ('redactedCount', redactedCount),
    ]) {
      if (value < 0) {
        throw ArgumentError.value(value, name, 'must be >= 0');
      }
    }
    if (rejectedCount > totalValidations) {
      throw ArgumentError.value(
        rejectedCount,
        'rejectedCount',
        'must be <= totalValidations',
      );
    }
    if (redactedCount > totalValidations) {
      throw ArgumentError.value(
        redactedCount,
        'redactedCount',
        'must be <= totalValidations',
      );
    }
    if (rejectedCount + redactedCount > totalValidations) {
      throw ArgumentError(
        'rejectedCount + redactedCount must be <= totalValidations',
      );
    }
  }

  final int totalValidations;
  final int rejectedCount;
  final int redactedCount;

  bool get isEmpty => totalValidations == 0;
}

/// Aggregate schema-validation diagnostics only. The caller maps registry
/// results to counts; this card never accepts event or parameter details.
class EventSchemaAuditCard extends StatelessWidget {
  EventSchemaAuditCard({
    super.key,
    required this.snapshot,
    this.title = 'Analytics schema audit',
    this.emptyLabel = 'No schema validations yet.',
    this.acceptedLabel = 'Accepted validations',
    this.rejectedLabel = 'Rejected validations',
    this.redactedLabel = 'Validations with redacted fields',
    this.deliveryNote =
        'Schema validation does not confirm analytics delivery.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('acceptedLabel', acceptedLabel),
      ('rejectedLabel', rejectedLabel),
      ('redactedLabel', redactedLabel),
      ('deliveryNote', deliveryNote),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final EventSchemaAuditSnapshot snapshot;
  final String title;
  final String emptyLabel;
  final String acceptedLabel;
  final String rejectedLabel;
  final String redactedLabel;
  final String deliveryNote;

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
            Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
            if (snapshot.isEmpty)
              Semantics(liveRegion: true, child: Text(emptyLabel))
            else ...[
              _CountRow(
                label: acceptedLabel,
                count: snapshot.totalValidations - snapshot.rejectedCount,
                icon: Icons.check_circle_outline,
              ),
              _CountRow(
                label: rejectedLabel,
                count: snapshot.rejectedCount,
                icon: Icons.cancel_outlined,
              ),
              _CountRow(
                label: redactedLabel,
                count: snapshot.redactedCount,
                icon: Icons.privacy_tip_outlined,
              ),
            ],
            Text(deliveryNote),
          ],
        ),
      ),
    ),
  );
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: NeonTheme.ink),
        const SizedBox(width: 8),
        Expanded(child: Text('$label: $count')),
      ],
    ),
  );
}
