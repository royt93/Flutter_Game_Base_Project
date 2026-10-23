import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum ConnectivityCardState { offline, checking, online, degraded }

/// Read-only connectivity summary. The coordinator owns the retry queue and
/// drains automatically once reachability is online; this card never receives
/// queued tasks or claims that work has drained.
class ConnectivityStatusCard extends StatefulWidget {
  ConnectivityStatusCard({
    super.key,
    required this.state,
    required this.queuedCount,
    this.onRetry,
    this.busy = false,
    this.title = 'Connection',
    this.offlineLabel = 'Offline',
    this.checkingLabel = 'Checking connection',
    this.onlineLabel = 'Online',
    this.degradedLabel = 'Connection unstable',
    this.queuedLabel = 'Waiting tasks',
    this.automaticDrainNote =
        'Waiting tasks run automatically when back online.',
    this.retryLabel = 'Retry connection check',
    this.errorLabel = 'Retry failed. Try again.',
  }) {
    if (queuedCount < 0) {
      throw ArgumentError.value(queuedCount, 'queuedCount', 'must be >= 0');
    }
    for (final (name, value) in [
      ('title', title),
      ('offlineLabel', offlineLabel),
      ('checkingLabel', checkingLabel),
      ('onlineLabel', onlineLabel),
      ('degradedLabel', degradedLabel),
      ('queuedLabel', queuedLabel),
      ('automaticDrainNote', automaticDrainNote),
      ('retryLabel', retryLabel),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final ConnectivityCardState state;
  final int queuedCount;
  final Future<void> Function()? onRetry;
  final bool busy;
  final String title;
  final String offlineLabel;
  final String checkingLabel;
  final String onlineLabel;
  final String degradedLabel;
  final String queuedLabel;
  final String automaticDrainNote;
  final String retryLabel;
  final String errorLabel;

  @override
  State<ConnectivityStatusCard> createState() => _ConnectivityStatusCardState();
}

class _ConnectivityStatusCardState extends State<ConnectivityStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy =>
      widget.busy || _running || widget.state == ConnectivityCardState.checking;

  bool get _canRetry =>
      widget.onRetry != null &&
      (widget.state == ConnectivityCardState.offline ||
          widget.state == ConnectivityCardState.degraded);

  @override
  void didUpdateWidget(covariant ConnectivityStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state || oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _retry() async {
    final action = widget.onRetry;
    if (_isBusy || !_canRetry || action == null) return;
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

  String get _stateLabel => switch (widget.state) {
    ConnectivityCardState.offline => widget.offlineLabel,
    ConnectivityCardState.checking => widget.checkingLabel,
    ConnectivityCardState.online => widget.onlineLabel,
    ConnectivityCardState.degraded => widget.degradedLabel,
  };

  IconData get _icon => switch (widget.state) {
    ConnectivityCardState.offline => Icons.wifi_off,
    ConnectivityCardState.checking => Icons.wifi_find,
    ConnectivityCardState.online => Icons.wifi,
    ConnectivityCardState.degraded =>
      Icons.signal_wifi_statusbar_connected_no_internet_4,
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
                child: Semantics(liveRegion: true, child: Text(_stateLabel)),
              ),
            ],
          ),
          Text('${widget.queuedLabel}: ${widget.queuedCount}'),
          Text(widget.automaticDrainNote),
          if (_failed) Text(widget.errorLabel),
          if (_canRetry) ...[
            const SizedBox(height: 8),
            CommonButton(
              key: const ValueKey('connectivityStatusRetry'),
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
