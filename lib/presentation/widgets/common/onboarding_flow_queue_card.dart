import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class OnboardingFlowRow {
  OnboardingFlowRow({
    required this.flowId,
    required this.label,
    required this.priority,
    required this.version,
    required this.isSeen,
    this.isNext = false,
  }) {
    if (flowId.trim().isEmpty) {
      throw ArgumentError.value(flowId, 'flowId', 'must not be blank');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'must be > 0');
    }
    if (isSeen && isNext) {
      throw ArgumentError.value(isNext, 'isNext', 'a seen flow cannot be next');
    }
  }

  /// Only identifies the row in callbacks; never rendered.
  final String flowId;
  final String label;
  final int priority;
  final int version;
  final bool isSeen;
  final bool isNext;
}

/// Read-only onboarding queue. The caller maps `isFlowSeen` and
/// `nextEligibleFlow` to rows; this card never receives the coordinator.
class OnboardingFlowQueueCard extends StatefulWidget {
  OnboardingFlowQueueCard({
    super.key,
    required List<OnboardingFlowRow> rows,
    this.onMarkSeen,
    this.busy = false,
    this.maxVisibleRows = 20,
    this.title = 'Onboarding flows',
    this.emptyLabel = 'No onboarding flows registered.',
    this.hiddenRowsLabel = 'More flows hidden',
    this.nextLabel = 'Next',
    this.seenLabel = 'Seen',
    this.pendingLabel = 'Not seen yet',
    this.priorityLabel = 'Priority',
    this.versionLabel = 'Version',
    this.markSeenLabel = 'Mark seen',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) : rows = List.unmodifiable(rows) {
    if (maxVisibleRows <= 0) {
      throw ArgumentError.value(
        maxVisibleRows,
        'maxVisibleRows',
        'must be > 0',
      );
    }
    if (this.rows.where((r) => r.isNext).length > 1) {
      throw ArgumentError.value(rows, 'rows', 'at most one row can be next');
    }
    if (this.rows.map((r) => r.flowId).toSet().length != this.rows.length) {
      throw ArgumentError.value(rows, 'rows', 'flowId values must be unique');
    }
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('hiddenRowsLabel', hiddenRowsLabel),
      ('nextLabel', nextLabel),
      ('seenLabel', seenLabel),
      ('pendingLabel', pendingLabel),
      ('priorityLabel', priorityLabel),
      ('versionLabel', versionLabel),
      ('markSeenLabel', markSeenLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<OnboardingFlowRow> rows;
  final Future<void> Function(String flowId)? onMarkSeen;
  final bool busy;
  final int maxVisibleRows;
  final String title;
  final String emptyLabel;
  final String hiddenRowsLabel;
  final String nextLabel;
  final String seenLabel;
  final String pendingLabel;
  final String priorityLabel;
  final String versionLabel;
  final String markSeenLabel;
  final String actionErrorLabel;

  @override
  State<OnboardingFlowQueueCard> createState() =>
      _OnboardingFlowQueueCardState();
}

class _OnboardingFlowQueueCardState extends State<OnboardingFlowQueueCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant OnboardingFlowQueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        !_sameRows(oldWidget.rows, widget.rows)) {
      _generation++;
      _failed = false;
    }
  }

  bool _sameRows(List<OnboardingFlowRow> a, List<OnboardingFlowRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].flowId != b[i].flowId ||
          a[i].label != b[i].label ||
          a[i].priority != b[i].priority ||
          a[i].version != b[i].version ||
          a[i].isSeen != b[i].isSeen ||
          a[i].isNext != b[i].isNext) {
        return false;
      }
    }
    return true;
  }

  Future<void> _markSeen(String flowId) async {
    final action = widget.onMarkSeen;
    if (_isBusy || action == null) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await action(flowId);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (generation == _generation) _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.rows.take(widget.maxVisibleRows).toList();
    final hidden = widget.rows.length - visible.length;
    return Semantics(
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
              if (widget.rows.isEmpty) Text(widget.emptyLabel),
              for (final row in visible)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        row.isSeen
                            ? Icons.check_circle_outline
                            : (row.isNext
                                  ? Icons.play_circle_outline
                                  : Icons.radio_button_unchecked),
                        color: NeonTheme.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.label),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                row.isSeen
                                    ? widget.seenLabel
                                    : (row.isNext
                                          ? widget.nextLabel
                                          : widget.pendingLabel),
                              ),
                            ),
                            Text(
                              '${widget.priorityLabel}: ${row.priority} · '
                              '${widget.versionLabel}: ${row.version}',
                            ),
                            if (widget.onMarkSeen != null && !row.isSeen)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: CommonButton(
                                  key: ValueKey(
                                    'onboardingMarkSeen_${row.flowId}',
                                  ),
                                  label: widget.markSeenLabel,
                                  variant: CommonButtonVariant.secondary,
                                  width: double.infinity,
                                  loading: _running,
                                  onTap: _isBusy
                                      ? null
                                      : () => _markSeen(row.flowId),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (hidden > 0) Text('${widget.hiddenRowsLabel}: $hidden'),
              if (_failed) Text(widget.actionErrorLabel),
            ],
          ),
        ),
      ),
    );
  }
}
