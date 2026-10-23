import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

/// Shows the exact, already-resolved announcement text a screen reader would
/// receive. The caller resolves it (locale, interpolation) and triggers the
/// real announcement through its own `GameAccessibilityAnnouncer`; this widget
/// never takes the event bus, announcer or translation map.
class AnnouncementPreviewCard extends StatefulWidget {
  AnnouncementPreviewCard({
    super.key,
    required this.messageText,
    required this.localeLabel,
    this.categoryLabel,
    this.throttleText,
    this.onPreview,
    this.busy = false,
    this.title = 'Screen reader announcement',
    this.messageLabel = 'Message',
    this.localeTitle = 'Language',
    this.categoryTitle = 'Category',
    this.throttleTitle = 'Repeat limit',
    this.previewLabel = 'Preview announcement',
    this.actionErrorLabel = 'Preview failed. Try again.',
  }) {
    for (final (name, value) in [
      ('messageText', messageText),
      ('localeLabel', localeLabel),
      ('categoryLabel', categoryLabel),
      ('throttleText', throttleText),
      ('title', title),
      ('messageLabel', messageLabel),
      ('localeTitle', localeTitle),
      ('categoryTitle', categoryTitle),
      ('throttleTitle', throttleTitle),
      ('previewLabel', previewLabel),
      ('actionErrorLabel', actionErrorLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String messageText;
  final String localeLabel;
  final String? categoryLabel;
  final String? throttleText;
  final Future<void> Function()? onPreview;
  final bool busy;
  final String title;
  final String messageLabel;
  final String localeTitle;
  final String categoryTitle;
  final String throttleTitle;
  final String previewLabel;
  final String actionErrorLabel;

  @override
  State<AnnouncementPreviewCard> createState() =>
      _AnnouncementPreviewCardState();
}

class _AnnouncementPreviewCardState extends State<AnnouncementPreviewCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant AnnouncementPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageText != widget.messageText ||
        oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _preview() async {
    final action = widget.onPreview;
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
            const SizedBox(height: 8),
            Text(widget.messageLabel, style: TextStyle(color: NeonTheme.ink)),
            Text(widget.messageText),
            Text('${widget.localeTitle}: ${widget.localeLabel}'),
            if (widget.categoryLabel != null)
              Text('${widget.categoryTitle}: ${widget.categoryLabel}'),
            if (widget.throttleText != null)
              Text('${widget.throttleTitle}: ${widget.throttleText}'),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onPreview != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('announcementPreview'),
                label: widget.previewLabel,
                width: double.infinity,
                loading: _running,
                onTap: _isBusy ? null : _preview,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
