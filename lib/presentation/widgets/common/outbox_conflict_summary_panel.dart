import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum OutboxConflictResolution { keepLocal, acceptRemote }

@immutable
class OutboxConflictSummary {
  OutboxConflictSummary({
    required this.reference,
    required this.localLabel,
    required this.remoteLabel,
    this.timestampText,
  }) {
    for (final (name, value) in [
      ('reference', reference),
      ('localLabel', localLabel),
      ('remoteLabel', remoteLabel),
      ('timestampText', timestampText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final String reference;
  final String localLabel;
  final String remoteLabel;
  final String? timestampText;
}

class OutboxConflictSummaryPanel extends StatelessWidget {
  OutboxConflictSummaryPanel({
    super.key,
    required this.conflicts,
    required this.onResolve,
    this.busy = false,
    this.title = 'Changes need review',
    this.keepLocalLabel = 'Keep local change',
    this.acceptRemoteLabel = 'Use remote version',
    this.confirmLabel = 'Confirm choice',
    this.cancelLabel = 'Cancel',
    this.keepLocalConfirmation =
        'Keep the local change in the queue to retry delivery later.',
    this.acceptRemoteConfirmation =
        'Remove this queued change. This does not undo changes already applied on this device.',
    this.errorLabel = 'Could not save this choice. Review and try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('keepLocalLabel', keepLocalLabel),
      ('acceptRemoteLabel', acceptRemoteLabel),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('keepLocalConfirmation', keepLocalConfirmation),
      ('acceptRemoteConfirmation', acceptRemoteConfirmation),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    final refs = <String>{};
    for (final conflict in conflicts) {
      if (!refs.add(conflict.reference)) {
        throw ArgumentError.value(
          conflicts,
          'conflicts',
          'duplicate opaque reference: ${conflict.reference}',
        );
      }
    }
  }

  final List<OutboxConflictSummary> conflicts;
  final Future<void> Function(
    String reference,
    OutboxConflictResolution resolution,
  )
  onResolve;
  final bool busy;
  final String title;
  final String keepLocalLabel;
  final String acceptRemoteLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String keepLocalConfirmation;
  final String acceptRemoteConfirmation;
  final String errorLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
            if (conflicts.isEmpty)
              const Text('No queued changes need review.')
            else
              for (final conflict in conflicts)
                _OutboxConflictRow(
                  key: ValueKey('outboxConflict_${conflict.reference}'),
                  conflict: conflict,
                  busy: busy,
                  keepLocalLabel: keepLocalLabel,
                  acceptRemoteLabel: acceptRemoteLabel,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                  keepLocalConfirmation: keepLocalConfirmation,
                  acceptRemoteConfirmation: acceptRemoteConfirmation,
                  errorLabel: errorLabel,
                  onResolve: onResolve,
                ),
          ],
        ),
      ),
    );
  }
}

class _OutboxConflictRow extends StatefulWidget {
  const _OutboxConflictRow({
    required this.conflict,
    required this.busy,
    required this.keepLocalLabel,
    required this.acceptRemoteLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.keepLocalConfirmation,
    required this.acceptRemoteConfirmation,
    required this.errorLabel,
    required this.onResolve,
    super.key,
  });

  final OutboxConflictSummary conflict;
  final bool busy;
  final String keepLocalLabel;
  final String acceptRemoteLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String keepLocalConfirmation;
  final String acceptRemoteConfirmation;
  final String errorLabel;
  final Future<void> Function(
    String reference,
    OutboxConflictResolution resolution,
  )
  onResolve;

  @override
  State<_OutboxConflictRow> createState() => _OutboxConflictRowState();
}

class _OutboxConflictRowState extends State<_OutboxConflictRow> {
  OutboxConflictResolution? _selected;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant _OutboxConflictRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conflict.reference != oldWidget.conflict.reference ||
        widget.busy != oldWidget.busy) {
      _generation++;
      _selected = null;
      _failed = false;
    }
  }

  Future<void> _resolve() async {
    final resolution = _selected;
    if (_busy || resolution == null) return;
    final reference = widget.conflict.reference;
    final generation = _generation;
    setState(() {
      _running = true;
      _selected = null;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onResolve(reference, resolution);
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.conflict.localLabel),
          Text('Remote: ${widget.conflict.remoteLabel}'),
          if (widget.conflict.timestampText != null)
            Text(widget.conflict.timestampText!),
          if (_failed) Text(widget.errorLabel),
          if (_selected == null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CommonButton(
                  key: ValueKey('outboxKeepLocal_${widget.conflict.reference}'),
                  label: widget.keepLocalLabel,
                  variant: CommonButtonVariant.secondary,
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _selected = OutboxConflictResolution.keepLocal;
                          _failed = false;
                        }),
                ),
                CommonButton(
                  key: ValueKey(
                    'outboxAcceptRemote_${widget.conflict.reference}',
                  ),
                  label: widget.acceptRemoteLabel,
                  variant: CommonButtonVariant.secondary,
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _selected = OutboxConflictResolution.acceptRemote;
                          _failed = false;
                        }),
                ),
              ],
            )
          else ...[
            Text(
              _selected == OutboxConflictResolution.keepLocal
                  ? widget.keepLocalConfirmation
                  : widget.acceptRemoteConfirmation,
            ),
            CommonButton(
              key: ValueKey(
                'outboxConflictConfirm_${widget.conflict.reference}',
              ),
              label: widget.confirmLabel,
              variant: CommonButtonVariant.danger,
              width: double.infinity,
              onTap: _busy ? null : _resolve,
            ),
            const SizedBox(height: 8),
            CommonButton(
              key: ValueKey(
                'outboxConflictCancel_${widget.conflict.reference}',
              ),
              label: widget.cancelLabel,
              variant: CommonButtonVariant.secondary,
              width: double.infinity,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _selected = null;
                      _failed = false;
                    }),
            ),
          ],
        ],
      ),
    );
  }
}
