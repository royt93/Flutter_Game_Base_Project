import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum OutboxQueueStatus { idle, draining, offline, error }

class OutboxQueueStatusCard extends StatelessWidget {
  OutboxQueueStatusCard({
    super.key,
    required this.pendingCount,
    required this.manualReviewCount,
    required this.status,
    this.busy = false,
    this.onDrain,
    this.title = 'Offline delivery queue',
    this.idleLabel = 'Waiting to sync',
    this.drainingLabel = 'Syncing queued changes',
    this.offlineLabel = 'Offline · changes stay on this device',
    this.errorLabel = 'Sync could not finish. Try again later.',
    this.pendingLabel = 'Pending',
    this.reviewLabel = 'Needs review',
    this.drainLabel = 'Sync now',
  }) {
    if (pendingCount < 0) {
      throw ArgumentError.value(pendingCount, 'pendingCount', 'must be >= 0');
    }
    if (manualReviewCount < 0) {
      throw ArgumentError.value(
        manualReviewCount,
        'manualReviewCount',
        'must be >= 0',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('idleLabel', idleLabel),
      ('drainingLabel', drainingLabel),
      ('offlineLabel', offlineLabel),
      ('errorLabel', errorLabel),
      ('pendingLabel', pendingLabel),
      ('reviewLabel', reviewLabel),
      ('drainLabel', drainLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final int pendingCount;
  final int manualReviewCount;
  final OutboxQueueStatus status;
  final bool busy;
  final Future<void> Function()? onDrain;
  final String title;
  final String idleLabel;
  final String drainingLabel;
  final String offlineLabel;
  final String errorLabel;
  final String pendingLabel;
  final String reviewLabel;
  final String drainLabel;

  @override
  Widget build(BuildContext context) {
    final draining = busy || status == OutboxQueueStatus.draining;
    final label = draining
        ? drainingLabel
        : switch (status) {
            OutboxQueueStatus.idle => idleLabel,
            OutboxQueueStatus.draining => drainingLabel,
            OutboxQueueStatus.offline => offlineLabel,
            OutboxQueueStatus.error => errorLabel,
          };
    final icon = switch (status) {
      OutboxQueueStatus.idle => Icons.cloud_queue_outlined,
      OutboxQueueStatus.draining => Icons.sync,
      OutboxQueueStatus.offline => Icons.cloud_off_outlined,
      OutboxQueueStatus.error => Icons.error_outline,
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
            Row(
              children: [
                Icon(icon, color: NeonTheme.ink),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ],
            ),
            Text(
              '$pendingLabel: $pendingCount · $reviewLabel: $manualReviewCount',
            ),
            if (onDrain != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('outboxDrain'),
                label: drainLabel,
                width: double.infinity,
                loading: draining,
                onTap: draining || status == OutboxQueueStatus.offline
                    ? null
                    : onDrain,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
