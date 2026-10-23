import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum DeepLinkResultStatus {
  dispatched,
  queued,
  duplicate,
  rejected,
  handlerFailed,
}

/// Generic deep-link outcome card. It never receives or renders the URI,
/// query parameters, router rejection message or handler exception, since
/// those can carry user data or tokens. Map `DeepLinkHandleResult` to
/// [status] in caller code: `dispatched` with all handlers succeeded ->
/// [DeepLinkResultStatus.dispatched]; `dispatched` with a failed handler ->
/// [DeepLinkResultStatus.handlerFailed]; `queuedUntilReady` -> queued;
/// `duplicateIgnored` -> duplicate; `rejected` -> rejected.
class DeepLinkResultCard extends StatefulWidget {
  DeepLinkResultCard({
    super.key,
    required this.status,
    this.onRetry,
    this.summaryText,
    this.busy = false,
    this.title = 'Link result',
    this.dispatchedLabel = 'Link opened',
    this.queuedLabel = 'Link will open when the app is ready',
    this.duplicateLabel = 'Link was already handled',
    this.rejectedLabel = 'This link is not valid',
    this.handlerFailedLabel = 'The link could not be completed',
    this.retryLabel = 'Try again',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('dispatchedLabel', dispatchedLabel),
      ('queuedLabel', queuedLabel),
      ('duplicateLabel', duplicateLabel),
      ('rejectedLabel', rejectedLabel),
      ('handlerFailedLabel', handlerFailedLabel),
      ('retryLabel', retryLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('summaryText', summaryText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final DeepLinkResultStatus status;
  final Future<void> Function()? onRetry;
  final String? summaryText;
  final bool busy;
  final String title;
  final String dispatchedLabel;
  final String queuedLabel;
  final String duplicateLabel;
  final String rejectedLabel;
  final String handlerFailedLabel;
  final String retryLabel;
  final String actionErrorLabel;

  @override
  State<DeepLinkResultCard> createState() => _DeepLinkResultCardState();
}

class _DeepLinkResultCardState extends State<DeepLinkResultCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  bool get _canRetry =>
      widget.onRetry != null &&
      (widget.status == DeepLinkResultStatus.rejected ||
          widget.status == DeepLinkResultStatus.handlerFailed);

  @override
  void didUpdateWidget(covariant DeepLinkResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _retry() async {
    final action = widget.onRetry;
    if (_isBusy || action == null) return;
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
    DeepLinkResultStatus.dispatched => widget.dispatchedLabel,
    DeepLinkResultStatus.queued => widget.queuedLabel,
    DeepLinkResultStatus.duplicate => widget.duplicateLabel,
    DeepLinkResultStatus.rejected => widget.rejectedLabel,
    DeepLinkResultStatus.handlerFailed => widget.handlerFailedLabel,
  };

  IconData get _icon => switch (widget.status) {
    DeepLinkResultStatus.dispatched => Icons.check_circle_outline,
    DeepLinkResultStatus.queued => Icons.schedule,
    DeepLinkResultStatus.duplicate => Icons.content_copy_outlined,
    DeepLinkResultStatus.rejected => Icons.link_off,
    DeepLinkResultStatus.handlerFailed => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(color: NeonTheme.ink, fontSize: 18),
          ),
          Row(
            children: [
              Icon(_icon, color: NeonTheme.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(liveRegion: true, child: Text(_statusLabel)),
              ),
            ],
          ),
          if (widget.summaryText != null) Text(widget.summaryText!),
          if (_failed) Text(widget.actionErrorLabel),
          if (_canRetry) ...[
            const SizedBox(height: 8),
            CommonButton(
              key: const ValueKey('deepLinkRetry'),
              label: widget.retryLabel,
              width: double.infinity,
              loading: _running,
              onTap: _isBusy ? null : _retry,
            ),
          ],
        ],
      ),
    ),
  );
}
