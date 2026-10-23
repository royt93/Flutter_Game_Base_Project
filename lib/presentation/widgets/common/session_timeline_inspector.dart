import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'panel_card.dart';

@immutable
class SessionTimelineRow {
  SessionTimelineRow({
    required this.offsetText,
    required this.phaseLabel,
    this.detailText,
  }) {
    for (final (name, value) in [
      ('offsetText', offsetText),
      ('phaseLabel', phaseLabel),
      ('detailText', detailText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  /// Caller-formatted session-relative offset, never a wall-clock timestamp.
  final String offsetText;
  final String phaseLabel;
  final String? detailText;
}

/// Read-only, bounded session timeline. The caller decides which metadata is
/// safe to include in each row; this widget never accepts a controller or raw
/// timeline entry.
class SessionTimelineInspector extends StatelessWidget {
  SessionTimelineInspector({
    super.key,
    required List<SessionTimelineRow> rows,
    this.durationText,
    this.terminalLabel,
    this.maxVisibleRows = 50,
    this.title = 'Session timeline',
    this.emptyLabel = 'No session transitions yet.',
    this.hiddenRowsLabel = 'Older transitions hidden.',
  }) : rows = List.unmodifiable(rows) {
    if (maxVisibleRows <= 0) {
      throw ArgumentError.value(
        maxVisibleRows,
        'maxVisibleRows',
        'must be > 0',
      );
    }
    for (final (name, value) in [
      ('durationText', durationText),
      ('terminalLabel', terminalLabel),
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('hiddenRowsLabel', hiddenRowsLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<SessionTimelineRow> rows;
  final String? durationText;
  final String? terminalLabel;
  final int maxVisibleRows;
  final String title;
  final String emptyLabel;
  final String hiddenRowsLabel;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.length > maxVisibleRows
        ? rows.skip(rows.length - maxVisibleRows).toList(growable: false)
        : rows;
    final hiddenCount = rows.length - visibleRows.length;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
              if (durationText != null) Text('Duration: $durationText'),
              if (terminalLabel != null) Text(terminalLabel!),
              if (rows.isEmpty) Text(emptyLabel),
              if (hiddenCount > 0) Text('$hiddenRowsLabel ($hiddenCount)'),
              for (final row in visibleRows) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.timeline, color: NeonTheme.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row.offsetText} · ${row.phaseLabel}'),
                          if (row.detailText != null) Text(row.detailText!),
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
}
