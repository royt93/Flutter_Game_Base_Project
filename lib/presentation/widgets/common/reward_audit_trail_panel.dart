import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum RewardAuditStatus { pending, partial, committed }

@immutable
class RewardAuditRow {
  RewardAuditRow({
    required this.sourceLabel,
    required this.timeText,
    required this.summaryText,
    required this.status,
  }) {
    for (final (name, value) in [
      ('sourceLabel', sourceLabel),
      ('timeText', timeText),
      ('summaryText', summaryText),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String sourceLabel;
  final String timeText;
  final String summaryText;
  final RewardAuditStatus status;
}

class RewardAuditTrailPanel extends StatefulWidget {
  RewardAuditTrailPanel({
    super.key,
    required List<RewardAuditRow> rows,
    this.onResumePending,
    this.busy = false,
    this.maxVisibleRows = 20,
    this.title = 'Reward audit trail',
    this.emptyLabel = 'No reward transactions yet.',
    this.hiddenRowsLabel = 'Older transactions hidden',
    this.pendingLabel = 'Pending',
    this.partialLabel = 'Partially applied',
    this.committedLabel = 'Committed',
    this.resumeLabel = 'Retry all unfinished rewards',
    this.retryNote =
        'Retry attempts all unfinished transactions. Some may remain unfinished.',
    this.summaryNote =
        'Summaries show recorded rewards, not per-line completion.',
    this.actionErrorLabel = 'Retry failed. Try again.',
  }) : rows = List.unmodifiable(rows) {
    if (maxVisibleRows <= 0) {
      throw ArgumentError.value(
        maxVisibleRows,
        'maxVisibleRows',
        'must be > 0',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('hiddenRowsLabel', hiddenRowsLabel),
      ('pendingLabel', pendingLabel),
      ('partialLabel', partialLabel),
      ('committedLabel', committedLabel),
      ('resumeLabel', resumeLabel),
      ('retryNote', retryNote),
      ('summaryNote', summaryNote),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  // Caller supplies sanitized rows in chronological order, oldest first.
  final List<RewardAuditRow> rows;
  final Future<void> Function()? onResumePending;
  final bool busy;
  final int maxVisibleRows;
  final String title;
  final String emptyLabel;
  final String hiddenRowsLabel;
  final String pendingLabel;
  final String partialLabel;
  final String committedLabel;
  final String resumeLabel;
  final String retryNote;
  final String summaryNote;
  final String actionErrorLabel;

  @override
  State<RewardAuditTrailPanel> createState() => _RewardAuditTrailPanelState();
}

class _RewardAuditTrailPanelState extends State<RewardAuditTrailPanel> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant RewardAuditTrailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        !_sameRows(oldWidget.rows, widget.rows)) {
      _generation++;
      _failed = false;
    }
  }

  bool _sameRows(List<RewardAuditRow> a, List<RewardAuditRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].sourceLabel != b[i].sourceLabel ||
          a[i].timeText != b[i].timeText ||
          a[i].summaryText != b[i].summaryText ||
          a[i].status != b[i].status) {
        return false;
      }
    }
    return true;
  }

  Future<void> _resume() async {
    final action = widget.onResumePending;
    if (_isBusy ||
        action == null ||
        !widget.rows.any((r) => r.status != RewardAuditStatus.committed)) {
      return;
    }
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

  String _label(RewardAuditStatus status) => switch (status) {
    RewardAuditStatus.pending => widget.pendingLabel,
    RewardAuditStatus.partial => widget.partialLabel,
    RewardAuditStatus.committed => widget.committedLabel,
  };

  @override
  Widget build(BuildContext context) {
    final hidden = (widget.rows.length - widget.maxVisibleRows).clamp(
      0,
      widget.rows.length,
    );
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
              if (hidden > 0) Text('${widget.hiddenRowsLabel}: $hidden'),
              for (final row in widget.rows.skip(hidden))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        row.status == RewardAuditStatus.committed
                            ? Icons.check_circle_outline
                            : Icons.pending_outlined,
                        color: NeonTheme.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row.sourceLabel} · ${row.timeText}'),
                            Semantics(
                              liveRegion: true,
                              child: Text(_label(row.status)),
                            ),
                            Text(row.summaryText),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(widget.summaryNote),
              Text(widget.retryNote),
              if (_failed) Text(widget.actionErrorLabel),
              if (widget.onResumePending != null) ...[
                const SizedBox(height: 8),
                CommonButton(
                  key: const ValueKey('rewardAuditResume'),
                  label: widget.resumeLabel,
                  width: double.infinity,
                  loading: _running,
                  onTap:
                      _isBusy ||
                          !widget.rows.any(
                            (r) => r.status != RewardAuditStatus.committed,
                          )
                      ? null
                      : _resume,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
