import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

/// In-app accessibility preview. Text scaling and target outlines are confined
/// to the preview subtree; this panel never changes app-wide settings.
class AccessibilityPreviewPanel extends StatefulWidget {
  AccessibilityPreviewPanel({
    super.key,
    required this.preview,
    this.targets = const <GlobalKey>[],
    this.onClose,
    this.closeLabel = 'Close preview',
    this.scaleLabel = 'Preview text size',
    this.targetLabel = 'Show touch targets',
    this.maxHeight = 560,
  }) {
    final unique = <GlobalKey>{};
    for (final key in targets) {
      if (!unique.add(key)) {
        throw ArgumentError.value(key, 'targets', 'keys must be unique');
      }
    }
    for (final (name, value) in [
      ('closeLabel', closeLabel),
      ('scaleLabel', scaleLabel),
      ('targetLabel', targetLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (!maxHeight.isFinite || maxHeight <= 0) {
      throw ArgumentError.value(
        maxHeight,
        'maxHeight',
        'must be finite and > 0',
      );
    }
  }

  final Widget preview;
  final List<GlobalKey> targets;
  final VoidCallback? onClose;
  final String closeLabel;
  final String scaleLabel;
  final String targetLabel;
  final double maxHeight;

  @override
  State<AccessibilityPreviewPanel> createState() =>
      _AccessibilityPreviewPanelState();
}

class _AccessibilityPreviewPanelState extends State<AccessibilityPreviewPanel> {
  final GlobalKey _viewportKey = GlobalKey();
  double _scale = 1;
  bool _showTargets = false;
  Map<GlobalKey, Rect> _targetRects = const {};
  bool _measureQueued = false;

  void _setScale(double scale) {
    if (scale == _scale) return;
    setState(() => _scale = scale);
    _scheduleMeasure();
  }

  void _setShowTargets(bool value) {
    if (value == _showTargets) return;
    setState(() => _showTargets = value);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measureQueued || !_showTargets) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted || !_showTargets) return;
      _measureTargets();
    });
  }

  void _measureTargets() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final origin = viewport.localToGlobal(Offset.zero);
    final bounds = Offset.zero & viewport.size;
    final rects = <GlobalKey, Rect>{};
    for (final key in widget.targets) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final global = box.localToGlobal(Offset.zero) - origin;
      final rect = (global & box.size).intersect(bounds);
      if (!rect.isEmpty) rects[key] = rect;
    }
    if (!mounted) return;
    setState(() => _targetRects = rects);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _scheduleMeasure();
    }
    return false;
  }

  Widget _scaleButton(BuildContext context, double scale) {
    final selected = _scale == scale;
    final label = '${(scale * 100).round()}%';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label ${widget.scaleLabel}',
      onTap: () => _setScale(scale),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => _setScale(scale),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? NeonTheme.purple.withValues(alpha: 0.15)
                : NeonTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? NeonTheme.purple : NeonTheme.inkSoft,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : widget.maxHeight;
      final height = math.min(widget.maxHeight, available);
      return SizedBox(
        width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    label: widget.scaleLabel,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final scale in const [1.0, 1.3, 2.0])
                          _scaleButton(context, scale),
                      ],
                    ),
                  ),
                  Semantics(
                    label: widget.targetLabel,
                    toggled: _showTargets,
                    onTap: () => _setShowTargets(!_showTargets),
                    child: GestureDetector(
                      key: const ValueKey('accessibilityTargetToggle'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setShowTargets(!_showTargets),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _showTargets
                              ? NeonTheme.purple.withValues(alpha: 0.15)
                              : NeonTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showTargets
                                ? NeonTheme.purple
                                : NeonTheme.inkSoft,
                            width: _showTargets ? 2 : 1,
                          ),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(widget.targetLabel),
                            const SizedBox(width: 4),
                            Icon(
                              _showTargets
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: NeonTheme.purple,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    Semantics(
                      label: widget.closeLabel,
                      child: CommonButton(
                        label: widget.closeLabel,
                        semanticLabel: widget.closeLabel,
                        onTap: widget.onClose,
                        width: 132,
                        variant: CommonButtonVariant.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: SingleChildScrollView(
                  key: const ValueKey('accessibilityPreviewScroll'),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(_scale)),
                    child: Stack(
                      key: _viewportKey,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        widget.preview,
                        if (_showTargets)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ExcludeSemantics(
                                child: Stack(
                                  children: [
                                    for (final entry in _targetRects.entries)
                                      Positioned.fromRect(
                                        rect: entry.value,
                                        child: DecoratedBox(
                                          key: ValueKey(
                                            'accessibilityTarget_${identityHashCode(entry.key)}',
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: NeonTheme.pink,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
