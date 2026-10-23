import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'panel_card.dart';

/// Presentation-only banner shown while the caller holds performance reduced
/// for low battery (for example `BatterySaverCoordinator.isForcingLow`).
/// Renders nothing when [active] is false.
class BatterySaverIndicator extends StatelessWidget {
  BatterySaverIndicator({
    super.key,
    required this.active,
    this.batteryPercent,
    this.title = 'Battery saver on',
    this.message = 'Decorative animations are reduced to save power.',
    this.percentLabel = 'Battery',
  }) {
    final percent = batteryPercent;
    if (percent != null && (percent < 0 || percent > 100)) {
      throw ArgumentError.value(percent, 'batteryPercent', 'must be 0..100');
    }
    for (final (name, value) in [
      ('title', title),
      ('message', message),
      ('percentLabel', percentLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final bool active;
  final int? batteryPercent;
  final String title;
  final String message;
  final String percentLabel;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: title,
      liveRegion: true,
      child: PanelCard(
        child: Row(
          children: [
            Icon(Icons.battery_saver_outlined, color: NeonTheme.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: NeonTheme.ink)),
                  Text(message),
                  if (batteryPercent != null)
                    Text('$percentLabel: $batteryPercent%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
