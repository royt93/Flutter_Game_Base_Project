import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum RemoteConfigHealthSource { unknown, assetOnly, remoteMerged, remoteFailed }

/// Safe remote-config diagnostics only: this card never accepts key/value data,
/// schema-violation strings, or a service instance.
class RemoteConfigHealthCard extends StatefulWidget {
  RemoteConfigHealthCard({
    super.key,
    required this.source,
    required this.violationCount,
    this.lastCheckedText,
    this.onRefresh,
    this.busy = false,
    this.title = 'Remote configuration',
    this.unknownLabel = 'Not checked yet',
    this.assetLabel = 'Using bundled settings',
    this.remoteLabel = 'Remote settings applied',
    this.fallbackLabel = 'Using bundled fallback settings',
    this.violationLabel = 'Schema violations',
    this.lastCheckedLabel = 'Last checked',
    this.refreshLabel = 'Refresh configuration',
    this.actionErrorLabel = 'Refresh failed. Try again.',
  }) {
    if (violationCount < 0) {
      throw ArgumentError.value(
        violationCount,
        'violationCount',
        'must be >= 0',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('unknownLabel', unknownLabel),
      ('assetLabel', assetLabel),
      ('remoteLabel', remoteLabel),
      ('fallbackLabel', fallbackLabel),
      ('violationLabel', violationLabel),
      ('lastCheckedLabel', lastCheckedLabel),
      ('refreshLabel', refreshLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('lastCheckedText', lastCheckedText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final RemoteConfigHealthSource source;
  final int violationCount;
  final String? lastCheckedText;
  final Future<void> Function()? onRefresh;
  final bool busy;
  final String title;
  final String unknownLabel;
  final String assetLabel;
  final String remoteLabel;
  final String fallbackLabel;
  final String violationLabel;
  final String lastCheckedLabel;
  final String refreshLabel;
  final String actionErrorLabel;

  @override
  State<RemoteConfigHealthCard> createState() => _RemoteConfigHealthCardState();
}

class _RemoteConfigHealthCardState extends State<RemoteConfigHealthCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant RemoteConfigHealthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.violationCount != widget.violationCount ||
        oldWidget.lastCheckedText != widget.lastCheckedText ||
        oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _refresh() async {
    final action = widget.onRefresh;
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

  String get _sourceLabel => switch (widget.source) {
    RemoteConfigHealthSource.unknown => widget.unknownLabel,
    RemoteConfigHealthSource.assetOnly => widget.assetLabel,
    RemoteConfigHealthSource.remoteMerged => widget.remoteLabel,
    RemoteConfigHealthSource.remoteFailed => widget.fallbackLabel,
  };

  IconData get _icon => switch (widget.source) {
    RemoteConfigHealthSource.unknown => Icons.help_outline,
    RemoteConfigHealthSource.assetOnly => Icons.inventory_2_outlined,
    RemoteConfigHealthSource.remoteMerged => Icons.cloud_done_outlined,
    RemoteConfigHealthSource.remoteFailed => Icons.cloud_off_outlined,
  };

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
            Row(
              children: [
                Icon(_icon, color: NeonTheme.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(_sourceLabel)),
                ),
              ],
            ),
            if (widget.violationCount > 0)
              Text('${widget.violationLabel}: ${widget.violationCount}'),
            if (widget.lastCheckedText != null)
              Text('${widget.lastCheckedLabel}: ${widget.lastCheckedText}'),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onRefresh != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('remoteConfigHealthRefresh'),
                label: widget.refreshLabel,
                width: double.infinity,
                loading: _running,
                onTap: _isBusy ? null : _refresh,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
