import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

class CandyRadioOption<T> {
  const CandyRadioOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.semanticLabel,
  });

  final T value;
  final String label;
  final String? subtitle;
  final String? semanticLabel;
}

class CandyRadioGroup<T> extends StatelessWidget {
  CandyRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.spacing = NeonTheme.s8,
  }) {
    if (options.isEmpty) {
      throw ArgumentError.value(options, 'options', 'must not be empty');
    }
    final values = <T>{};
    for (final option in options) {
      if (!values.add(option.value)) {
        throw ArgumentError.value(
          option.value,
          'options',
          'values must be unique',
        );
      }
    }
    if (value != null && !values.contains(value)) {
      throw ArgumentError.value(value, 'value', 'must match an option value');
    }
    if (spacing < 0 || !spacing.isFinite) {
      throw ArgumentError.value(
        spacing,
        'spacing',
        'must be finite and non-negative',
      );
    }
  }

  final List<CandyRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final Color? activeColor;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < options.length; i++) ...[
        _CandyChoiceTile(
          label: options[i].label,
          subtitle: options[i].subtitle,
          semanticLabel: options[i].semanticLabel,
          selected: value == options[i].value,
          checked: false,
          activeColor: activeColor ?? NeonTheme.cyan,
          enabled: onChanged != null,
          onTap: onChanged == null ? null : () => onChanged!(options[i].value),
        ),
        if (i < options.length - 1) SizedBox(height: spacing),
      ],
    ],
  );
}

class CandyCheckboxTile extends StatelessWidget {
  const CandyCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.semanticLabel,
    this.activeColor,
  });

  final String label;
  final String? subtitle;
  final String? semanticLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => _CandyChoiceTile(
    label: label,
    subtitle: subtitle,
    semanticLabel: semanticLabel,
    selected: value,
    checked: true,
    activeColor: activeColor ?? NeonTheme.lime,
    enabled: onChanged != null,
    onTap: onChanged == null ? null : () => onChanged!(!value),
  );
}

class _CandyChoiceTile extends StatelessWidget {
  const _CandyChoiceTile({
    required this.label,
    required this.subtitle,
    required this.semanticLabel,
    required this.selected,
    required this.checked,
    required this.activeColor,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final String? semanticLabel;
  final bool selected;
  final bool checked;
  final Color activeColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? activeColor : NeonTheme.muted;
    final duration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final marker = checked
        ? Icon(Icons.check_rounded, size: 19, color: Colors.white)
        : Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          );

    return Semantics(
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      checked: checked ? selected : null,
      inMutuallyExclusiveGroup: !checked,
      selected: !checked ? selected : null,
      label: semanticLabel ?? label,
      value: subtitle,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : NeonTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : NeonTheme.cardAlt,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: enabled ? NeonTheme.drop(y: 2, blur: 5) : null,
          ),
          child: Row(
            children: [
              AnimatedScale(
                duration: duration,
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: marker,
                ),
              ),
              if (!selected) ...[
                const SizedBox(width: 28),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ],
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
