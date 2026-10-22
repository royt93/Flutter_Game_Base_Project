import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum SaveConflictChoice { local, cloud }

@immutable
class SaveConflictSummary {
  SaveConflictSummary({
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

class SaveConflictPicker extends StatefulWidget {
  SaveConflictPicker({
    super.key,
    required this.local,
    required this.cloud,
    required this.onResolve,
    this.busy = false,
    this.title = 'Choose a save',
    this.localLabel = 'This device',
    this.cloudLabel = 'Cloud',
    this.confirmLabel = 'Keep selected save',
    this.cancelLabel = 'Cancel',
    this.keepLabel = 'Keep',
    this.replaceLabel = 'Replace',
    this.confirmationText =
        'The selected save will replace the other progress. This cannot be undone.',
    this.errorLabel = 'Could not apply this choice. Select again to retry.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('localLabel', localLabel),
      ('cloudLabel', cloudLabel),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('keepLabel', keepLabel),
      ('replaceLabel', replaceLabel),
      ('confirmationText', confirmationText),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final SaveConflictSummary local;
  final SaveConflictSummary cloud;
  final Future<void> Function(
    SaveConflictChoice choice,
    String localRevision,
    String cloudRevision,
  )
  onResolve;
  final bool busy;
  final String title;
  final String localLabel;
  final String cloudLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String keepLabel;
  final String replaceLabel;
  final String confirmationText;
  final String errorLabel;

  @override
  State<SaveConflictPicker> createState() => _SaveConflictPickerState();
}

class _SaveConflictPickerState extends State<SaveConflictPicker> {
  SaveConflictChoice? _selected;
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _busy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant SaveConflictPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.local.revision != oldWidget.local.revision ||
        widget.cloud.revision != oldWidget.cloud.revision ||
        widget.busy != oldWidget.busy) {
      _generation++;
      _selected = null;
      _failed = false;
    }
  }

  Future<void> _resolve() async {
    final choice = _selected;
    if (_busy || choice == null) return;
    final localRevision = widget.local.revision;
    final cloudRevision = widget.cloud.revision;
    final generation = _generation;
    setState(() {
      _running = true;
      _selected = null;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onResolve(choice, localRevision, cloudRevision);
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
            for (final choice in SaveConflictChoice.values) ...[
              const SizedBox(height: 8),
              Text(
                choice == SaveConflictChoice.local
                    ? widget.localLabel
                    : widget.cloudLabel,
              ),
              Text(
                choice == SaveConflictChoice.local
                    ? widget.local.savedAtText
                    : widget.cloud.savedAtText,
              ),
              Text(
                choice == SaveConflictChoice.local
                    ? widget.local.progressText
                    : widget.cloud.progressText,
              ),
              Semantics(
                selected: _selected == choice,
                child: CommonButton(
                  key: ValueKey('saveConflict_${choice.name}'),
                  label: choice == SaveConflictChoice.local
                      ? widget.localLabel
                      : widget.cloudLabel,
                  icon: _selected == choice ? Icons.check : null,
                  variant: CommonButtonVariant.secondary,
                  width: double.infinity,
                  onTap: _busy || _selected != null
                      ? null
                      : () => setState(() {
                          _selected = choice;
                          _failed = false;
                        }),
                ),
              ),
            ],
            if (_failed) Text(widget.errorLabel),
            if (_selected != null) ...[
              const SizedBox(height: 8),
              Text(widget.confirmationText),
              Text(
                '${widget.keepLabel}: ${_selected == SaveConflictChoice.local ? widget.localLabel : widget.cloudLabel}',
              ),
              Text(
                '${widget.replaceLabel}: ${_selected == SaveConflictChoice.local ? widget.cloudLabel : widget.localLabel}',
              ),
              CommonButton(
                key: const ValueKey('saveConflictConfirm'),
                label: widget.confirmLabel,
                variant: CommonButtonVariant.danger,
                width: double.infinity,
                onTap: _busy ? null : _resolve,
              ),
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('saveConflictCancel'),
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
            if (_running)
              CommonButton(
                label: widget.confirmLabel,
                loading: true,
                width: double.infinity,
                onTap: null,
              ),
          ],
        ),
      ),
    );
  }
}
