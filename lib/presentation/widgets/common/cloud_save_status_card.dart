import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum CloudSaveStatus { ready, syncing, synced, offline, error }

class CloudSaveStatusCard extends StatefulWidget {
  CloudSaveStatusCard({
    super.key,
    required this.status,
    this.pendingCount = 0,
    this.lastSyncText,
    this.onSync,
    this.busy = false,
    this.title = 'Cloud save',
    this.readyLabel = 'Ready to sync',
    this.syncingLabel = 'Syncing',
    this.syncedLabel = 'Synced',
    this.offlineLabel = 'Offline',
    this.errorLabel = 'Sync failed. Try again.',
    this.pendingLabel = 'Pending changes',
    this.syncLabel = 'Sync now',
    this.retryLabel = 'Retry sync',
  }) {
    if (pendingCount < 0) {
      throw ArgumentError.value(pendingCount, 'pendingCount', 'must be >= 0');
    }
    for (final (name, value) in [
      ('title', title),
      ('readyLabel', readyLabel),
      ('syncingLabel', syncingLabel),
      ('syncedLabel', syncedLabel),
      ('offlineLabel', offlineLabel),
      ('errorLabel', errorLabel),
      ('pendingLabel', pendingLabel),
      ('syncLabel', syncLabel),
      ('retryLabel', retryLabel),
      ('lastSyncText', lastSyncText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final CloudSaveStatus status;
  final int pendingCount;
  final String? lastSyncText;
  final Future<void> Function()? onSync;
  final bool busy;
  final String title;
  final String readyLabel;
  final String syncingLabel;
  final String syncedLabel;
  final String offlineLabel;
  final String errorLabel;
  final String pendingLabel;
  final String syncLabel;
  final String retryLabel;

  @override
  State<CloudSaveStatusCard> createState() => _CloudSaveStatusCardState();
}

class _CloudSaveStatusCardState extends State<CloudSaveStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy =>
      widget.busy || _running || widget.status == CloudSaveStatus.syncing;

  @override
  void didUpdateWidget(covariant CloudSaveStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status || widget.busy != oldWidget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _sync() async {
    if (_busy || widget.status == CloudSaveStatus.offline) return;
    final action = widget.onSync;
    if (action == null) return;
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
    final failed = _failed || widget.status == CloudSaveStatus.error;
    final status = _busy
        ? widget.syncingLabel
        : failed
        ? widget.errorLabel
        : switch (widget.status) {
            CloudSaveStatus.ready => widget.readyLabel,
            CloudSaveStatus.syncing => widget.syncingLabel,
            CloudSaveStatus.synced => widget.syncedLabel,
            CloudSaveStatus.offline => widget.offlineLabel,
            CloudSaveStatus.error => widget.errorLabel,
          };
    final icon = _busy
        ? Icons.sync
        : failed
        ? Icons.error_outline
        : switch (widget.status) {
            CloudSaveStatus.offline => Icons.cloud_off,
            CloudSaveStatus.synced => Icons.cloud_done,
            _ => Icons.cloud_outlined,
          };
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
                Icon(icon, color: NeonTheme.ink),
                const SizedBox(width: 8),
                Expanded(child: Text(status)),
              ],
            ),
            Semantics(
              label: '${widget.pendingLabel}: ${widget.pendingCount}',
              child: ExcludeSemantics(
                child: Text('${widget.pendingLabel}: ${widget.pendingCount}'),
              ),
            ),
            if (widget.lastSyncText != null) Text(widget.lastSyncText!),
            if (widget.onSync != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('cloudSaveSync'),
                label: failed ? widget.retryLabel : widget.syncLabel,
                width: double.infinity,
                loading: _busy,
                onTap: _busy || widget.status == CloudSaveStatus.offline
                    ? null
                    : _sync,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
