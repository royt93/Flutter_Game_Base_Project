import 'package:flutter/material.dart';

import 'countdown_chip.dart';

/// Adapter over [CountdownChip] for a keyed cooldown read from
/// `PersistentCooldownService` — takes plain [remaining] data rather than
/// reaching into the service directly (same convention as `EnergyBar`/
/// `LevelSelectGrid`: widgets take data, callers own the GetX service).
///
/// Renders nothing while [remaining] is zero (cooldown ready — nothing to
/// count down). [remaining] is only converted into a fixed [DateTime]
/// target once, at mount and whenever it actually changes value — a parent
/// rebuild that passes the same [remaining] again (e.g. an unrelated `Obx`
/// tick) does not reset the underlying countdown.
class CooldownCountdownChip extends StatefulWidget {
  const CooldownCountdownChip({
    super.key,
    required this.remaining,
    this.onDone,
    this.icon = Icons.timer_outlined,
    this.color,
    this.fontSize = 14,
    this.semanticLabel,
  });

  final Duration remaining;
  final VoidCallback? onDone;
  final IconData icon;
  final Color? color;
  final double fontSize;
  final String? semanticLabel;

  @override
  State<CooldownCountdownChip> createState() => _CooldownCountdownChipState();
}

class _CooldownCountdownChipState extends State<CooldownCountdownChip> {
  late DateTime _target = DateTime.now().add(widget.remaining);

  @override
  void didUpdateWidget(covariant CooldownCountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) {
      _target = DateTime.now().add(widget.remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remaining <= Duration.zero) return const SizedBox.shrink();
    return CountdownChip(
      target: _target,
      onDone: widget.onDone,
      icon: widget.icon,
      color: widget.color,
      fontSize: widget.fontSize,
      semanticLabel: widget.semanticLabel,
    );
  }
}
