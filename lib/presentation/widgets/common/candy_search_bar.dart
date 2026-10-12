import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'candy_text_field.dart';
import '../pressable_scale.dart';

class CandySearchBar extends StatefulWidget {
  const CandySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.semanticLabel = 'Search items',
    this.debounce = const Duration(milliseconds: 300),
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final String semanticLabel;
  final Duration debounce;

  @override
  State<CandySearchBar> createState() => _CandySearchBarState();
}

class _CandySearchBarState extends State<CandySearchBar> {
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_handleControllerChange);
    _validate();
  }

  void _validate() {
    if (widget.debounce < Duration.zero) {
      throw ArgumentError.value(
        widget.debounce,
        'debounce',
        'must not be negative',
      );
    }
  }

  void _handleControllerChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  void _scheduleChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      if (mounted) widget.onChanged(value);
    });
  }

  void _clear() {
    widget.controller.clear();
    _scheduleChanged('');
  }

  @override
  void didUpdateWidget(covariant CandySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate();
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _hasText = widget.controller.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          label: widget.semanticLabel,
          textField: true,
          child: CandyTextField(
            controller: widget.controller,
            hintText: widget.hintText,
            prefixIcon: Icons.search_rounded,
            onChanged: _scheduleChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
      if (_hasText) ...[
        const SizedBox(width: NeonTheme.s8),
        Semantics(
          button: true,
          label: 'Clear search',
          onTap: _clear,
          child: PressableScale(
            key: const ValueKey('candySearchClear'),
            onTap: _clear,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NeonTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: NeonTheme.cardAlt, width: 2),
              ),
              child: Icon(Icons.close_rounded, color: NeonTheme.inkSoft),
            ),
          ),
        ),
      ],
    ],
  );
}

class CandyFilter<T> {
  const CandyFilter({required this.value, required this.label});

  final T value;
  final String label;
}

class FilterChipRow<T> extends StatelessWidget {
  FilterChipRow({
    super.key,
    required this.filters,
    required this.selectedValues,
    required this.onChanged,
    this.spacing = NeonTheme.s8,
    this.semanticLabel = 'Filters',
  }) {
    if (filters.map((filter) => filter.value).toSet().length !=
        filters.length) {
      throw ArgumentError.value(filters, 'filters', 'values must be unique');
    }
    if (spacing < 0 || !spacing.isFinite) {
      throw ArgumentError.value(
        spacing,
        'spacing',
        'must be finite and non-negative',
      );
    }
  }

  final List<CandyFilter<T>> filters;
  final Set<T> selectedValues;
  final ValueChanged<Set<T>> onChanged;
  final double spacing;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              _FilterChip<T>(
                key: ValueKey(('filter', filters[i].value)),
                filter: filters[i],
                selected: selectedValues.contains(filters[i].value),
                onTap: () {
                  final next = Set<T>.of(selectedValues);
                  if (!next.add(filters[i].value)) {
                    next.remove(filters[i].value);
                  }
                  onChanged(Set<T>.unmodifiable(next));
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final CandyFilter<T> filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = NeonTheme.motionDuration(
      context,
      const Duration(milliseconds: 180),
    );
    final color = selected ? NeonTheme.cyan : NeonTheme.card;
    return Semantics(
      button: true,
      selected: selected,
      label: filter.label,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : NeonTheme.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : NeonTheme.cardAlt,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: duration,
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: selected ? NeonTheme.s8 : 0,
                  ),
                  child: Icon(Icons.check_rounded, size: 16, color: color),
                ),
              ),
              Text(
                filter.label,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
