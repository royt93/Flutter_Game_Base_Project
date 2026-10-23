import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'panel_card.dart';

@immutable
class PlatformCapabilityRow {
  PlatformCapabilityRow({
    required this.label,
    required this.supported,
    this.noteText,
  }) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (noteText != null && noteText!.trim().isEmpty) {
      throw ArgumentError.value(noteText, 'noteText', 'must not be blank');
    }
  }

  final String label;
  final bool supported;
  final String? noteText;
}

/// Read-only platform capability list. Support is shown by icon and text, not
/// colour alone. The caller maps `PlatformCapabilitySnapshot` to rows; those
/// values are the registry's policy defaults, not a live platform probe.
class PlatformCapabilityMatrix extends StatelessWidget {
  PlatformCapabilityMatrix({
    super.key,
    required this.platformLabel,
    required List<PlatformCapabilityRow> rows,
    this.title = 'Platform capabilities',
    this.supportedLabel = 'Supported',
    this.unsupportedLabel = 'Not supported',
    this.disclaimer = 'Defaults for this platform, not a live check.',
  }) : rows = List.unmodifiable(rows) {
    if (rows.isEmpty) {
      throw ArgumentError.value(rows, 'rows', 'must not be empty');
    }
    final labels = <String>{};
    for (final row in rows) {
      if (!labels.add(row.label)) {
        throw ArgumentError.value(row.label, 'rows', 'duplicate label');
      }
    }
    for (final (name, value) in [
      ('platformLabel', platformLabel),
      ('title', title),
      ('supportedLabel', supportedLabel),
      ('unsupportedLabel', unsupportedLabel),
      ('disclaimer', disclaimer),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String platformLabel;
  final List<PlatformCapabilityRow> rows;
  final String title;
  final String supportedLabel;
  final String unsupportedLabel;
  final String disclaimer;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: '$title, $platformLabel',
    child: PanelCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
            Text(platformLabel),
            for (final row in rows) ...[
              const SizedBox(height: 8),
              Semantics(
                container: true,
                label:
                    '${row.label}: ${row.supported ? supportedLabel : unsupportedLabel}',
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        row.supported
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: NeonTheme.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.label,
                              style: TextStyle(color: NeonTheme.ink),
                            ),
                            Text(
                              row.supported ? supportedLabel : unsupportedLabel,
                            ),
                            if (row.noteText != null) Text(row.noteText!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(disclaimer),
          ],
        ),
      ),
    ),
  );
}
