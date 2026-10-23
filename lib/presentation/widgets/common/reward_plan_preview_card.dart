import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum RewardPlanPreviewStatus { ready, stale, executing, applied, failed }

@immutable
class RewardPlanPreviewLine {
  RewardPlanPreviewLine({required this.label, required this.amountText}) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (amountText.trim().isEmpty) {
      throw ArgumentError.value(amountText, 'amountText', 'must not be blank');
    }
  }

  final String label;
  final String amountText;
}

class RewardPlanPreviewCard extends StatefulWidget {
  RewardPlanPreviewCard({
    super.key,
    required List<RewardPlanPreviewLine> lines,
    required this.status,
    this.onConfirm,
    this.onRefresh,
    this.onCancel,
    this.busy = false,
    this.title = 'Reward preview',
    this.readyLabel = 'Ready to apply',
    this.staleLabel = 'Preview is out of date. Refresh before applying.',
    this.executingLabel = 'Applying rewards',
    this.appliedLabel = 'Rewards applied',
    this.failedLabel = 'Rewards were not fully applied.',
    this.emptyLabel = 'No rewards in this preview.',
    this.previewNote = 'A preview is not a grant. Availability may change.',
    this.confirmLabel = 'Apply these rewards',
    this.refreshLabel = 'Refresh preview',
    this.cancelLabel = 'Cancel',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) : lines = List.unmodifiable(lines) {
    for (final (name, value) in [
      ('title', title),
      ('readyLabel', readyLabel),
      ('staleLabel', staleLabel),
      ('executingLabel', executingLabel),
      ('appliedLabel', appliedLabel),
      ('failedLabel', failedLabel),
      ('emptyLabel', emptyLabel),
      ('previewNote', previewNote),
      ('confirmLabel', confirmLabel),
      ('refreshLabel', refreshLabel),
      ('cancelLabel', cancelLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<RewardPlanPreviewLine> lines;
  final RewardPlanPreviewStatus status;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onCancel;
  final bool busy;
  final String title;
  final String readyLabel;
  final String staleLabel;
  final String executingLabel;
  final String appliedLabel;
  final String failedLabel;
  final String emptyLabel;
  final String previewNote;
  final String confirmLabel;
  final String refreshLabel;
  final String cancelLabel;
  final String actionErrorLabel;

  @override
  State<RewardPlanPreviewCard> createState() => _RewardPlanPreviewCardState();
}

class _RewardPlanPreviewCardState extends State<RewardPlanPreviewCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy =>
      _running ||
      widget.busy ||
      widget.status == RewardPlanPreviewStatus.executing;

  @override
  void didUpdateWidget(covariant RewardPlanPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.busy != widget.busy ||
        !_sameLines(oldWidget.lines, widget.lines)) {
      _generation++;
      _failed = false;
    }
  }

  bool _sameLines(
    List<RewardPlanPreviewLine> a,
    List<RewardPlanPreviewLine> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label || a[i].amountText != b[i].amountText) {
        return false;
      }
    }
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await action();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (generation == _generation) _failed = failed;
    });
  }

  String get _statusLabel => switch (widget.status) {
    RewardPlanPreviewStatus.ready => widget.readyLabel,
    RewardPlanPreviewStatus.stale => widget.staleLabel,
    RewardPlanPreviewStatus.executing => widget.executingLabel,
    RewardPlanPreviewStatus.applied => widget.appliedLabel,
    RewardPlanPreviewStatus.failed => widget.failedLabel,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: PanelCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: NeonTheme.ink, fontSize: 18),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.status == RewardPlanPreviewStatus.applied
                      ? Icons.check_circle_outline
                      : Icons.card_giftcard,
                  color: NeonTheme.ink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(_statusLabel)),
                ),
              ],
            ),
            if (widget.lines.isEmpty) Text(widget.emptyLabel),
            for (final line in widget.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${line.label}: ${line.amountText}'),
              ),
            Text(widget.previewNote),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onConfirm != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('rewardPlanConfirm'),
                label: widget.confirmLabel,
                width: double.infinity,
                loading: _running,
                onTap:
                    _isBusy ||
                        widget.status != RewardPlanPreviewStatus.ready ||
                        widget.lines.isEmpty
                    ? null
                    : () => _run(widget.onConfirm!),
              ),
            ],
            if (widget.onRefresh != null &&
                (widget.status == RewardPlanPreviewStatus.stale ||
                    widget.status == RewardPlanPreviewStatus.failed)) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('rewardPlanRefresh'),
                label: widget.refreshLabel,
                width: double.infinity,
                onTap: _isBusy ? null : () => _run(widget.onRefresh!),
              ),
            ],
            if (widget.onCancel != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('rewardPlanCancel'),
                label: widget.cancelLabel,
                variant: CommonButtonVariant.secondary,
                width: double.infinity,
                onTap: _isBusy ? null : widget.onCancel,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
