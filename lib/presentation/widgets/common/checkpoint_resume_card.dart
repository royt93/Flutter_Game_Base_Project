import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

@immutable
class CheckpointSummary {
  CheckpointSummary({
    required this.revision,
    required this.savedAtText,
    required this.progressText,
  }) {
    for (final (name, value) in [
      ('revision', revision),
      ('savedAtText', savedAtText),
      ('progressText', progressText),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String revision;
  final String savedAtText;
  final String progressText;
}

class CheckpointResumeCard extends StatefulWidget {
  CheckpointResumeCard({
    super.key,
    required this.checkpoint,
    required this.onResume,
    this.onStartNew,
    this.busy = false,
    this.title = 'Continue your game',
    this.emptyLabel = 'No checkpoint available',
    this.resumeLabel = 'Resume',
    this.startNewLabel = 'Start new game',
    this.confirmLabel = 'Discard checkpoint',
    this.cancelLabel = 'Cancel',
    this.confirmationText =
        'Starting a new game discards this checkpoint. This cannot be undone.',
    this.errorLabel = 'Action failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('emptyLabel', emptyLabel),
      ('resumeLabel', resumeLabel),
      ('startNewLabel', startNewLabel),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('confirmationText', confirmationText),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final CheckpointSummary? checkpoint;
  final Future<void> Function(String revision) onResume;
  final Future<void> Function(String revision)? onStartNew;
  final bool busy;
  final String title;
  final String emptyLabel;
  final String resumeLabel;
  final String startNewLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String confirmationText;
  final String errorLabel;

  @override
  State<CheckpointResumeCard> createState() => _CheckpointResumeCardState();
}

class _CheckpointResumeCardState extends State<CheckpointResumeCard> {
  bool _confirming = false;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant CheckpointResumeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkpoint?.revision != oldWidget.checkpoint?.revision ||
        widget.busy != oldWidget.busy ||
        (widget.onStartNew == null) != (oldWidget.onStartNew == null)) {
      _generation++;
      _confirming = false;
      _failed = false;
    }
  }

  Future<void> _run({required bool startNew}) async {
    final checkpoint = widget.checkpoint;
    if (_busy || checkpoint == null || (startNew && !_confirming)) return;
    final action = startNew ? widget.onStartNew : widget.onResume;
    if (action == null) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _confirming = false;
      _failed = false;
    });
    var failed = false;
    try {
      await action(checkpoint.revision);
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
    final checkpoint = widget.checkpoint;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: NeonTheme.ink, fontSize: 18),
            ),
            if (checkpoint == null)
              Text(widget.emptyLabel)
            else ...[
              Text(checkpoint.savedAtText),
              Text(checkpoint.progressText),
              if (_failed) Text(widget.errorLabel),
              const SizedBox(height: 8),
              if (_confirming) ...[
                Text(widget.confirmationText),
                CommonButton(
                  key: const ValueKey('checkpointConfirm'),
                  label: widget.confirmLabel,
                  variant: CommonButtonVariant.danger,
                  width: double.infinity,
                  onTap: _busy ? null : () => _run(startNew: true),
                ),
                const SizedBox(height: 8),
                CommonButton(
                  key: const ValueKey('checkpointCancel'),
                  label: widget.cancelLabel,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _busy
                      ? null
                      : () => setState(() => _confirming = false),
                ),
              ] else ...[
                CommonButton(
                  key: const ValueKey('checkpointResume'),
                  label: widget.resumeLabel,
                  width: double.infinity,
                  loading: _running,
                  onTap: _busy ? null : () => _run(startNew: false),
                ),
                if (widget.onStartNew != null) ...[
                  const SizedBox(height: 8),
                  CommonButton(
                    key: const ValueKey('checkpointStartNew'),
                    label: widget.startNewLabel,
                    variant: CommonButtonVariant.secondary,
                    width: double.infinity,
                    onTap: _busy
                        ? null
                        : () => setState(() {
                            _confirming = true;
                            _failed = false;
                          }),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
