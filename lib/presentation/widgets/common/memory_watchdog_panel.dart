import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class WatchdogRow {
  WatchdogRow({
    required this.kindLabel,
    required this.ownerText,
    required this.ageText,
    this.labelText,
  }) {
    for (final (name, value) in [
      ('kindLabel', kindLabel),
      ('ownerText', ownerText),
      ('ageText', ageText),
      ('labelText', labelText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String kindLabel;

  /// Caller-approved owner text; the caller decides whether it is safe to show.
  final String ownerText;
  final String ageText;
  final String? labelText;
}

/// Read-only view of caller-built memory watchdog rows. It never reads
/// `MemoryWatchdog`. The watchdog is a debug-only leak detector, not leak
/// prevention, and reports nothing in release builds.
class MemoryWatchdogPanel extends StatefulWidget {
  MemoryWatchdogPanel({
    super.key,
    required List<WatchdogRow> orphans,
    required List<WatchdogRow> recentlyDisposed,
    this.onRefresh,
    this.busy = false,
    this.maxRows = 20,
    this.title = 'Resource watchdog',
    this.note =
        'Debug detector only. It does not prevent leaks and reports nothing in release builds.',
    this.orphansTitle = 'Still live',
    this.disposedTitle = 'Recently disposed',
    this.noOrphansLabel = 'No leak candidates.',
    this.noDisposedLabel = 'Nothing disposed yet.',
    this.hiddenRowsLabel = 'more hidden',
    this.refreshLabel = 'Refresh',
    this.actionErrorLabel = 'Refresh failed. Try again.',
  }) : orphans = List.unmodifiable(orphans),
       recentlyDisposed = List.unmodifiable(recentlyDisposed) {
    if (maxRows <= 0) {
      throw ArgumentError.value(maxRows, 'maxRows', 'must be > 0');
    }
    for (final (name, value) in [
      ('title', title),
      ('note', note),
      ('orphansTitle', orphansTitle),
      ('disposedTitle', disposedTitle),
      ('noOrphansLabel', noOrphansLabel),
      ('noDisposedLabel', noDisposedLabel),
      ('hiddenRowsLabel', hiddenRowsLabel),
      ('refreshLabel', refreshLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final List<WatchdogRow> orphans;
  final List<WatchdogRow> recentlyDisposed;
  final Future<void> Function()? onRefresh;
  final bool busy;
  final int maxRows;
  final String title;
  final String note;
  final String orphansTitle;
  final String disposedTitle;
  final String noOrphansLabel;
  final String noDisposedLabel;
  final String hiddenRowsLabel;
  final String refreshLabel;
  final String actionErrorLabel;

  @override
  State<MemoryWatchdogPanel> createState() => _MemoryWatchdogPanelState();
}

class _MemoryWatchdogPanelState extends State<MemoryWatchdogPanel> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant MemoryWatchdogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) {
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

  List<Widget> _section(
    String heading,
    List<WatchdogRow> rows,
    String emptyLabel,
  ) {
    final visible = rows.length > widget.maxRows
        ? rows.take(widget.maxRows).toList(growable: false)
        : rows;
    final hidden = rows.length - visible.length;
    return [
      const SizedBox(height: 12),
      Text(heading, style: TextStyle(color: NeonTheme.ink)),
      if (rows.isEmpty) Text(emptyLabel),
      for (final row in visible)
        Text(
          '${row.kindLabel} · ${row.ownerText} · ${row.ageText}'
          '${row.labelText == null ? '' : ' · ${row.labelText}'}',
        ),
      if (hidden > 0) Text('+$hidden ${widget.hiddenRowsLabel}'),
    ];
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
            Text(widget.note),
            ..._section(
              widget.orphansTitle,
              widget.orphans,
              widget.noOrphansLabel,
            ),
            ..._section(
              widget.disposedTitle,
              widget.recentlyDisposed,
              widget.noDisposedLabel,
            ),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onRefresh != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('watchdogRefresh'),
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
