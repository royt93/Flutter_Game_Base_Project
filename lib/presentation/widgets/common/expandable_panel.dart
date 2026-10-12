import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

class ExpandablePanel extends StatefulWidget {
  const ExpandablePanel({
    super.key,
    required this.header,
    required this.content,
    this.isExpanded = false,
    this.onExpansionChanged,
    this.duration = const Duration(milliseconds: 250),
    this.lazy = true,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget header;
  final Widget content;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Duration duration;
  final bool lazy;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  State<ExpandablePanel> createState() => ExpandablePanelState();
}

class ExpandablePanelState extends State<ExpandablePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _height;
  late final Animation<double> _chevron;
  bool _hasExpanded = false;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _validate();
    _hasExpanded = widget.isExpanded;
    _expanded = widget.isExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isExpanded ? 1 : 0,
    );
    _height = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _chevron = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  void _validate() {
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context)) {
      _controller.value = widget.isExpanded ? 1 : 0;
      if (widget.isExpanded) _hasExpanded = true;
    }
  }

  @override
  void didUpdateWidget(covariant ExpandablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate();
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isExpanded != widget.isExpanded) {
      _setExpanded(widget.isExpanded, notify: false);
    }
  }

  void _setExpanded(bool expanded, {required bool notify}) {
    _expanded = expanded;
    if (expanded) _hasExpanded = true;
    if (NeonTheme.reducedMotion(context)) {
      _controller.value = expanded ? 1 : 0;
    } else if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    if (notify) widget.onExpansionChanged?.call(expanded);
  }

  void toggle() {
    final next = !_expanded;
    setState(() => _expanded = next);
    _setExpanded(next, notify: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final showContent = widget.lazy ? _hasExpanded : true;
    final color = widget.borderColor ?? NeonTheme.cyan;

    return Container(
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: NeonTheme.drop(y: 2, blur: 5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            key: const ValueKey('expandablePanelHeader'),
            container: true,
            button: true,
            enabled: true,
            expanded: expanded,
            label: widget.semanticLabel,
            onTap: toggle,
            child: PressableScale(
              onTap: toggle,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s16,
                ),
                child: Row(
                  children: [
                    Expanded(child: widget.header),
                    RotationTransition(
                      turns: _chevron.drive(Tween<double>(begin: 0, end: 0.5)),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showContent)
            ClipRect(
              child: ExcludeSemantics(
                excluding: !_expanded,
                child: IgnorePointer(
                  ignoring: !_expanded,
                  child: SizeTransition(
                    sizeFactor: _height,
                    axisAlignment: -1,
                    axis: Axis.vertical,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: NeonTheme.s16,
                        end: NeonTheme.s16,
                        bottom: NeonTheme.s16,
                      ),
                      child: widget.content,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
