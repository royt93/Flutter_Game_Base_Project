import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum ContentPackStatus { loading, ready, refreshing, error }

class ContentPackStatusCard extends StatefulWidget {
  ContentPackStatusCard({
    super.key,
    required this.status,
    required this.contentVersion,
    this.updatedAtText,
    this.busy = false,
    this.onRefresh,
    this.title = 'Content pack',
    this.loadingLabel = 'Loading content',
    this.readyLabel = 'Content ready',
    this.refreshingLabel = 'Updating content',
    this.errorLabel = 'Content update failed. Try again.',
    this.versionLabel = 'Version',
    this.updatedLabel = 'Updated',
    this.refreshLabel = 'Refresh content',
    this.retryLabel = 'Retry update',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) {
    if (contentVersion < 0) {
      throw ArgumentError.value(
        contentVersion,
        'contentVersion',
        'must be >= 0',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('loadingLabel', loadingLabel),
      ('readyLabel', readyLabel),
      ('refreshingLabel', refreshingLabel),
      ('errorLabel', errorLabel),
      ('versionLabel', versionLabel),
      ('updatedLabel', updatedLabel),
      ('refreshLabel', refreshLabel),
      ('retryLabel', retryLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('updatedAtText', updatedAtText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final ContentPackStatus status;
  final int contentVersion;
  final String? updatedAtText;
  final bool busy;
  final Future<void> Function()? onRefresh;
  final String title;
  final String loadingLabel;
  final String readyLabel;
  final String refreshingLabel;
  final String errorLabel;
  final String versionLabel;
  final String updatedLabel;
  final String refreshLabel;
  final String retryLabel;
  final String actionErrorLabel;

  @override
  State<ContentPackStatusCard> createState() => _ContentPackStatusCardState();
}

class _ContentPackStatusCardState extends State<ContentPackStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running || _isLoading;

  bool get _isLoading =>
      widget.status == ContentPackStatus.loading ||
      widget.status == ContentPackStatus.refreshing;

  @override
  void didUpdateWidget(covariant ContentPackStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status || widget.busy != oldWidget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final action = widget.onRefresh;
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
    final failure = _failed || widget.status == ContentPackStatus.error;
    final statusLabel = _busy
        ? (widget.status == ContentPackStatus.loading
              ? widget.loadingLabel
              : widget.refreshingLabel)
        : failure
        ? widget.errorLabel
        : widget.readyLabel;
    final icon = _busy
        ? Icons.downloading_outlined
        : failure
        ? Icons.error_outline
        : Icons.inventory_2_outlined;
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
                Expanded(child: Text(statusLabel)),
              ],
            ),
            Text('${widget.versionLabel}: ${widget.contentVersion}'),
            if (widget.updatedAtText != null)
              Text('${widget.updatedLabel}: ${widget.updatedAtText}'),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onRefresh != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('contentPackRefresh'),
                label: failure ? widget.retryLabel : widget.refreshLabel,
                width: double.infinity,
                loading: _busy,
                onTap: _busy ? null : _refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
