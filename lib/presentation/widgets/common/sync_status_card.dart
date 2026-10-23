import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum SyncStatus { idle, syncing, synced, failed }

/// Presentation-only sync status with a manual sync/retry button, for the
/// achievement or leaderboard seams. The caller runs the sync (for example
/// `AchievementSyncCoordinator.sync`) and maps its result to [status]; this
/// widget never reads a service or shows an exception. A callback that
/// returns without throwing is not shown as success: only [status] is.
class SyncStatusCard extends StatefulWidget {
  SyncStatusCard({
    super.key,
    required this.status,
    required this.onSync,
    this.lastSyncedText,
    this.busy = false,
    this.title = 'Sync',
    this.idleLabel = 'Not synced yet',
    this.syncingLabel = 'Syncing',
    this.syncedLabel = 'Up to date',
    this.failedLabel = 'Sync failed. Try again.',
    this.lastSyncedLabel = 'Last synced',
    this.syncLabel = 'Sync now',
    this.retryLabel = 'Retry sync',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('idleLabel', idleLabel),
      ('syncingLabel', syncingLabel),
      ('syncedLabel', syncedLabel),
      ('failedLabel', failedLabel),
      ('lastSyncedLabel', lastSyncedLabel),
      ('syncLabel', syncLabel),
      ('retryLabel', retryLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('lastSyncedText', lastSyncedText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final SyncStatus status;
  final Future<void> Function() onSync;
  final String? lastSyncedText;
  final bool busy;
  final String title;
  final String idleLabel;
  final String syncingLabel;
  final String syncedLabel;
  final String failedLabel;
  final String lastSyncedLabel;
  final String syncLabel;
  final String retryLabel;
  final String actionErrorLabel;

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy =>
      widget.busy || _running || widget.status == SyncStatus.syncing;

  @override
  void didUpdateWidget(covariant SyncStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status || widget.busy != oldWidget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onSync();
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
    final failure = _failed || widget.status == SyncStatus.failed;
    final label = _busy
        ? widget.syncingLabel
        : failure
        ? widget.failedLabel
        : widget.status == SyncStatus.synced
        ? widget.syncedLabel
        : widget.idleLabel;
    final icon = _busy
        ? Icons.sync
        : failure
        ? Icons.sync_problem_outlined
        : widget.status == SyncStatus.synced
        ? Icons.cloud_done_outlined
        : Icons.cloud_outlined;
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
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(label)),
                ),
              ],
            ),
            if (widget.lastSyncedText != null)
              Text('${widget.lastSyncedLabel}: ${widget.lastSyncedText}'),
            if (_failed) Text(widget.actionErrorLabel),
            const SizedBox(height: 8),
            CommonButton(
              key: const ValueKey('syncStatusAction'),
              label: failure ? widget.retryLabel : widget.syncLabel,
              width: double.infinity,
              loading: _busy,
              onTap: _busy ? null : _sync,
            ),
          ],
        ),
      ),
    );
  }
}
