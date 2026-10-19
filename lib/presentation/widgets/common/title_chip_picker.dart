import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// One caller-owned player title.
@immutable
class TitleOption {
  TitleOption({
    required this.id,
    required this.label,
    this.locked = false,
    this.unlockHint,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (unlockHint != null && unlockHint!.trim().isEmpty) {
      throw ArgumentError.value(unlockHint, 'unlockHint', 'must not be blank');
    }
  }

  final String id;
  final String label;
  final bool locked;
  final String? unlockHint;
}

/// Wrap-layout title selector with caller-owned unlock and selection state.
class TitleChipPicker extends StatelessWidget {
  TitleChipPicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.onLockedTap,
    this.noneLabel = 'No title',
    this.selectedLabel = 'Equipped',
    this.lockedLabel = 'Locked',
    this.semanticLabel,
  }) {
    final ids = <String>{};
    for (final option in options) {
      if (!ids.add(option.id)) {
        throw ArgumentError.value(option.id, 'options', 'duplicate id');
      }
    }
    if (selectedId != null) {
      final selected = options.where((option) => option.id == selectedId);
      if (selected.isEmpty) {
        throw ArgumentError.value(
          selectedId,
          'selectedId',
          'must be null or an option id',
        );
      }
      if (selected.first.locked) {
        throw ArgumentError.value(
          selectedId,
          'selectedId',
          'must not be a locked title',
        );
      }
    }
    for (final (name, value) in [
      ('noneLabel', noneLabel),
      ('selectedLabel', selectedLabel),
      ('lockedLabel', lockedLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (semanticLabel != null && semanticLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        semanticLabel,
        'semanticLabel',
        'must not be blank',
      );
    }
  }

  final List<TitleOption> options;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String>? onLockedTap;
  final String noneLabel;
  final String selectedLabel;
  final String lockedLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final spacing = 8 * scale;
    final children = <Widget>[
      _chip(
        key: const ValueKey('titleChip_none'),
        id: null,
        label: noneLabel,
        locked: false,
        selected: selectedId == null,
        unlockHint: null,
      ),
      for (final option in options)
        _chip(
          key: ValueKey('titleChip_${option.id}'),
          id: option.id,
          label: option.label,
          locked: option.locked,
          selected: option.id == selectedId,
          unlockHint: option.unlockHint,
        ),
    ];
    final selectedName = selectedId == null
        ? noneLabel
        : options.firstWhere((o) => o.id == selectedId).label;
    final spoken = semanticLabel ?? 'Title, $selectedName';
    final wrap = Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: children,
    );
    return Semantics(container: true, label: spoken, child: wrap);
  }

  Widget _chip({
    required Key key,
    required String? id,
    required String label,
    required bool locked,
    required bool selected,
    required String? unlockHint,
  }) {
    final inert = locked && onLockedTap == null;
    final onTap = inert || selected
        ? null
        : () => locked ? onLockedTap?.call(id!) : onSelect(id);
    final accent = locked
        ? NeonTheme.muted
        : selected
        ? NeonTheme.purple
        : NeonTheme.cyan;
    final spoken = selected
        ? '$label, $selectedLabel'
        : locked
        ? '$label, $lockedLabel${unlockHint == null ? '' : ', $unlockHint'}'
        : label;
    final color = locked ? NeonTheme.inkSoft : NeonTheme.ink;
    final chip = Container(
      key: key,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.18) : NeonTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: selected ? 0.95 : 0.5),
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            Icon(Icons.lock_rounded, size: 15, color: color),
            const SizedBox(width: 5),
          ] else if (selected) ...[
            Icon(Icons.check_rounded, size: 15, color: accent),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.2,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: !inert,
      enabled: !inert,
      selected: selected,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: PressableScale(onTap: onTap, child: chip),
      ),
    );
  }
}
