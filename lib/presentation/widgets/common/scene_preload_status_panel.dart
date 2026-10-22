import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum ScenePreloadStatus { idle, loading, ready, error, cancelled }

class ScenePreloadStatusPanel extends StatefulWidget {
  ScenePreloadStatusPanel({
    super.key,
    required this.sceneId,
    required this.status,
    required this.progress,
    required this.itemCount,
    this.busy = false,
    this.onStart,
    this.onRetry,
    this.onCancel,
    this.title = 'Scene assets',
    this.idleLabel = 'Ready to preload',
    this.loadingLabel = 'Preparing scene',
    this.readyLabel = 'Scene ready',
    this.errorLabel = 'Some required assets failed to load.',
    this.cancelledLabel = 'Preload cancelled',
    this.itemCountLabel = 'Assets',
    this.startLabel = 'Preload',
    this.retryLabel = 'Retry failed assets',
    this.cancelLabel = 'Cancel preload',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) {
    if (sceneId.trim().isEmpty) {
      throw ArgumentError.value(sceneId, 'sceneId', 'must not be blank');
    }
    if (itemCount < 0) {
      throw ArgumentError.value(itemCount, 'itemCount', 'must be >= 0');
    }
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(
        progress,
        'progress',
        'must be finite and in 0..1',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('idleLabel', idleLabel),
      ('loadingLabel', loadingLabel),
      ('readyLabel', readyLabel),
      ('errorLabel', errorLabel),
      ('cancelledLabel', cancelledLabel),
      ('itemCountLabel', itemCountLabel),
      ('startLabel', startLabel),
      ('retryLabel', retryLabel),
      ('cancelLabel', cancelLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String sceneId;
  final ScenePreloadStatus status;
  final double progress;
  final int itemCount;
  final bool busy;
  final Future<void> Function()? onStart;
  final Future<void> Function()? onRetry;
  final VoidCallback? onCancel;
  final String title;
  final String idleLabel;
  final String loadingLabel;
  final String readyLabel;
  final String errorLabel;
  final String cancelledLabel;
  final String itemCountLabel;
  final String startLabel;
  final String retryLabel;
  final String cancelLabel;
  final String actionErrorLabel;

  @override
  State<ScenePreloadStatusPanel> createState() =>
      _ScenePreloadStatusPanelState();
}

class _ScenePreloadStatusPanelState extends State<ScenePreloadStatusPanel> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running || _isLoading;

  bool get _isLoading => widget.status == ScenePreloadStatus.loading;

  @override
  void didUpdateWidget(covariant ScenePreloadStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sceneId != oldWidget.sceneId ||
        widget.status != oldWidget.status ||
        widget.busy != oldWidget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (_busy || action == null) return;
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
      if (_generation == generation) _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failed || widget.status == ScenePreloadStatus.error;
    final statusLabel = _busy
        ? widget.loadingLabel
        : failure
        ? widget.errorLabel
        : switch (widget.status) {
            ScenePreloadStatus.idle => widget.idleLabel,
            ScenePreloadStatus.loading => widget.loadingLabel,
            ScenePreloadStatus.ready => widget.readyLabel,
            ScenePreloadStatus.error => widget.errorLabel,
            ScenePreloadStatus.cancelled => widget.cancelledLabel,
          };
    final progressLabel = '${(widget.progress * 100).toStringAsFixed(0)}%';
    final startable =
        widget.status == ScenePreloadStatus.idle ||
        widget.status == ScenePreloadStatus.cancelled;
    final retryable = widget.status == ScenePreloadStatus.error;
    final cancellable = widget.status == ScenePreloadStatus.loading;
    return Semantics(
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
                Expanded(child: Text(widget.sceneId)),
                Text('${widget.itemCountLabel}: ${widget.itemCount}'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _isLoading ? null : widget.progress,
                  ),
                ),
                const SizedBox(width: 8),
                Text(progressLabel),
              ],
            ),
            Row(
              children: [
                Icon(
                  failure ? Icons.error_outline : Icons.downloading_outlined,
                  color: failure ? NeonTheme.red : NeonTheme.ink,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(statusLabel)),
              ],
            ),
            if (_failed) Text(widget.actionErrorLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (startable && widget.onStart != null)
                  CommonButton(
                    key: const ValueKey('scenePreloadStart'),
                    label: widget.startLabel,
                    loading: _busy,
                    onTap: _busy ? null : () => _run(widget.onStart),
                  ),
                if (retryable && widget.onRetry != null)
                  CommonButton(
                    key: const ValueKey('scenePreloadRetry'),
                    label: widget.retryLabel,
                    loading: _busy,
                    onTap: _busy ? null : () => _run(widget.onRetry),
                  ),
                if (cancellable && widget.onCancel != null)
                  CommonButton(
                    key: const ValueKey('scenePreloadCancel'),
                    label: widget.cancelLabel,
                    variant: CommonButtonVariant.secondary,
                    onTap: widget.busy || widget.onCancel == null
                        ? null
                        : widget.onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
