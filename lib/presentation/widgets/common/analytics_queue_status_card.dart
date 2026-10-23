import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class AnalyticsQueueSnapshot {
  AnalyticsQueueSnapshot({
    required this.pendingCount,
    required this.uploadedCount,
    required Map<String, int> droppedCounts,
  }) : droppedCounts = Map.unmodifiable(droppedCounts) {
    for (final (name, value) in [
      ('pendingCount', pendingCount),
      ('uploadedCount', uploadedCount),
    ]) {
      if (value < 0) throw ArgumentError.value(value, name, 'must be >= 0');
    }
    for (final entry in droppedCounts.entries) {
      if (entry.key.trim().isEmpty || entry.value < 0) {
        throw ArgumentError.value(entry, 'droppedCounts', 'invalid entry');
      }
    }
  }

  final int pendingCount;
  final int uploadedCount;

  /// Caller-labelled reason counters only; no event data or identifiers.
  final Map<String, int> droppedCounts;

  int get totalDropped =>
      droppedCounts.values.fold(0, (sum, count) => sum + count);
}

/// Aggregate-only analytics queue status. The caller maps queue audit counts
/// to [snapshot] and runs [onFlush]; this card never accepts events, event
/// names, parameters or a queue instance.
class AnalyticsQueueStatusCard extends StatefulWidget {
  AnalyticsQueueStatusCard({
    super.key,
    required this.snapshot,
    this.onFlush,
    this.consentGranted = true,
    this.busy = false,
    this.title = 'Private analytics queue',
    this.pendingLabel = 'Pending',
    this.uploadedLabel = 'Uploaded',
    this.droppedLabel = 'Dropped',
    this.droppedByReasonLabel = 'Dropped by reason',
    this.consentRequiredLabel = 'Analytics consent not granted',
    this.flushLabel = 'Upload pending analytics',
    this.flushingLabel = 'Uploading analytics',
    this.errorLabel = 'Upload failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('pendingLabel', pendingLabel),
      ('uploadedLabel', uploadedLabel),
      ('droppedLabel', droppedLabel),
      ('droppedByReasonLabel', droppedByReasonLabel),
      ('consentRequiredLabel', consentRequiredLabel),
      ('flushLabel', flushLabel),
      ('flushingLabel', flushingLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final AnalyticsQueueSnapshot snapshot;
  final Future<void> Function()? onFlush;
  final bool consentGranted;
  final bool busy;
  final String title;
  final String pendingLabel;
  final String uploadedLabel;
  final String droppedLabel;
  final String droppedByReasonLabel;
  final String consentRequiredLabel;
  final String flushLabel;
  final String flushingLabel;
  final String errorLabel;

  @override
  State<AnalyticsQueueStatusCard> createState() =>
      _AnalyticsQueueStatusCardState();
}

class _AnalyticsQueueStatusCardState extends State<AnalyticsQueueStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant AnalyticsQueueStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        oldWidget.consentGranted != widget.consentGranted ||
        oldWidget.snapshot.pendingCount != widget.snapshot.pendingCount) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _flush() async {
    final action = widget.onFlush;
    if (_isBusy || !widget.consentGranted || action == null) return;
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

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: PanelCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: NeonTheme.ink, fontSize: 18),
            ),
            Text('${widget.pendingLabel}: ${widget.snapshot.pendingCount}'),
            Text('${widget.uploadedLabel}: ${widget.snapshot.uploadedCount}'),
            Text('${widget.droppedLabel}: ${widget.snapshot.totalDropped}'),
            if (widget.snapshot.droppedCounts.isNotEmpty) ...[
              Text(widget.droppedByReasonLabel),
              for (final entry in widget.snapshot.droppedCounts.entries)
                Text('${entry.key}: ${entry.value}'),
            ],
            if (!widget.consentGranted)
              Text(widget.consentRequiredLabel)
            else if (widget.onFlush != null) ...[
              if (_failed) Text(widget.errorLabel),
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('analyticsQueueFlush'),
                label: widget.flushLabel,
                width: double.infinity,
                loading: _running,
                onTap: _isBusy ? null : _flush,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
