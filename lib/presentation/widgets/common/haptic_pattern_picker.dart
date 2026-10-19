import 'package:flutter/material.dart';

import '../../../core/haptic_choreographer.dart';
import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// One named, caller-supplied haptic pattern.
@immutable
class HapticPatternOption {
  const HapticPatternOption({
    required this.id,
    required this.label,
    required this.pattern,
  });

  final String id;
  final String label;
  final HapticPattern pattern;
}

/// Select and preview a short haptic pattern. The caller owns preference state
/// and playback; the widget never constructs a [HapticChoreographer].
class HapticPatternPicker extends StatelessWidget {
  HapticPatternPicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    required this.onPreview,
    this.hapticsEnabled = true,
    this.busy = false,
    this.previewLabel = 'Preview',
    this.busyLabel = 'Playing',
    this.disabledLabel = 'Haptics off',
    this.semanticLabel = 'Haptic pattern',
  }) {
    if (options.isEmpty || options.length > 3) {
      throw ArgumentError.value(options.length, 'options', 'must be in 1..3');
    }
    final ids = <String>{};
    for (final option in options) {
      if (option.id.trim().isEmpty) {
        throw ArgumentError.value(option.id, 'options', 'id must not be blank');
      }
      if (!ids.add(option.id)) {
        throw ArgumentError.value(option.id, 'options', 'duplicate id');
      }
      if (option.label.trim().isEmpty) {
        throw ArgumentError.value(
          option.label,
          'options',
          'label must not be blank',
        );
      }
    }
    if (selectedId != null && !ids.contains(selectedId)) {
      throw ArgumentError.value(
        selectedId,
        'selectedId',
        'must be null or an option id',
      );
    }
    for (final (name, value) in [
      ('previewLabel', previewLabel),
      ('busyLabel', busyLabel),
      ('disabledLabel', disabledLabel),
      ('semanticLabel', semanticLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<HapticPatternOption> options;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<HapticPattern> onPreview;
  final bool hapticsEnabled;
  final bool busy;
  final String previewLabel;
  final String busyLabel;
  final String disabledLabel;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final option in options) _option(option), _option(null)],
    ),
  );

  Widget _option(HapticPatternOption? option) {
    final id = option?.id;
    final selected = selectedId == id;
    final enabled = !busy;
    final label = option?.label ?? 'Off';
    final spoken =
        '$label${selected ? ', selected' : ''}${busy ? ', $busyLabel' : ''}';
    final color = selected ? NeonTheme.purple : NeonTheme.cyan;
    final canPreview = option != null && hapticsEnabled && !busy;
    final actionLabel = busy
        ? busyLabel
        : !hapticsEnabled
        ? disabledLabel
        : previewLabel;
    final semantic = '$semanticLabel $label, $actionLabel';

    return Semantics(
      container: true,
      label: spoken,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: enabled,
              label: spoken,
              onTap: enabled ? () => onSelect(id) : null,
              excludeSemantics: true,
              child: PressableScale(
                onTap: enabled ? () => onSelect(id) : null,
                child: Container(
                  key: ValueKey('hapticOption_${id ?? 'off'}'),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.16)
                        : NeonTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : NeonTheme.inkSoft,
                      width: selected ? 2.5 : 1.25,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        Icon(Icons.check_rounded, color: color, size: 16),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              enabled: canPreview,
              label: semantic,
              onTap: canPreview ? () => onPreview(option.pattern) : null,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('hapticPreview_${id ?? 'off'}'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: canPreview ? () => onPreview(option.pattern) : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Center(
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      style: TextStyle(
                        color: canPreview ? color : NeonTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
