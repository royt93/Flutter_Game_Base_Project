import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum ReplayVerificationStatus { notChecked, matched, diverged, invalid }

enum ReplayRngCheckStatus { notChecked, matched, mismatched }

/// Only caller-mapped status and safe copy; never raw replay data or secrets.
class ReplayVerificationResultCard extends StatefulWidget {
  ReplayVerificationResultCard({
    super.key,
    required this.status,
    required this.checkedOutcomeCount,
    this.rngStatus = ReplayRngCheckStatus.notChecked,
    this.rngMismatchCount = 0,
    this.divergenceIndex,
    this.onVerifyAgain,
    this.busy = false,
    this.summaryText,
    this.title = 'Replay verification',
    this.notCheckedLabel = 'No replay comparison was checked.',
    this.matchedLabel = 'Checked recorded outcomes matched.',
    this.divergedLabel = 'Checked recorded outcomes differed.',
    this.invalidLabel = 'Replay could not be verified.',
    this.rngNotCheckedLabel = 'Randomness check was not run.',
    this.rngMatchedLabel = 'Checked randomness state matched.',
    this.rngMismatchedLabel = 'Randomness state differed',
    this.comparedOutcomesLabel = 'Compared outcomes',
    this.comparisonIndexLabel = 'Compared outcome index',
    this.caveatLabel =
        'Only checked outcomes are summarized. This is not proof of fair play.',
    this.verifyLabel = 'Verify again',
    this.actionErrorLabel = 'Verification failed. Try again.',
  }) {
    if (checkedOutcomeCount < 0) {
      throw ArgumentError.value(
        checkedOutcomeCount,
        'checkedOutcomeCount',
        'must be >= 0',
      );
    }
    if (rngMismatchCount < 0) {
      throw ArgumentError.value(
        rngMismatchCount,
        'rngMismatchCount',
        'must be >= 0',
      );
    }
    if ((status == ReplayVerificationStatus.matched ||
            status == ReplayVerificationStatus.diverged) &&
        checkedOutcomeCount == 0) {
      throw ArgumentError.value(
        checkedOutcomeCount,
        'checkedOutcomeCount',
        'must be > 0 for matched or diverged status',
      );
    }
    if (status == ReplayVerificationStatus.notChecked &&
        checkedOutcomeCount != 0) {
      throw ArgumentError.value(
        checkedOutcomeCount,
        'checkedOutcomeCount',
        'must be 0 when comparisons were not checked',
      );
    }
    final index = divergenceIndex;
    if (index != null &&
        (status != ReplayVerificationStatus.diverged ||
            index < 0 ||
            index >= checkedOutcomeCount)) {
      throw ArgumentError.value(
        divergenceIndex,
        'divergenceIndex',
        'must identify a checked outcome in diverged status',
      );
    }
    if (rngStatus == ReplayRngCheckStatus.mismatched
        ? rngMismatchCount == 0
        : rngMismatchCount != 0) {
      throw ArgumentError.value(
        rngMismatchCount,
        'rngMismatchCount',
        'must be > 0 only when RNG state mismatched',
      );
    }
    for (final (name, value) in [
      ('title', title),
      ('notCheckedLabel', notCheckedLabel),
      ('matchedLabel', matchedLabel),
      ('divergedLabel', divergedLabel),
      ('invalidLabel', invalidLabel),
      ('rngNotCheckedLabel', rngNotCheckedLabel),
      ('rngMatchedLabel', rngMatchedLabel),
      ('rngMismatchedLabel', rngMismatchedLabel),
      ('comparedOutcomesLabel', comparedOutcomesLabel),
      ('comparisonIndexLabel', comparisonIndexLabel),
      ('caveatLabel', caveatLabel),
      ('verifyLabel', verifyLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('summaryText', summaryText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final ReplayVerificationStatus status;
  final int checkedOutcomeCount;
  final ReplayRngCheckStatus rngStatus;
  final int rngMismatchCount;
  final int? divergenceIndex;
  final Future<void> Function()? onVerifyAgain;
  final bool busy;
  final String? summaryText;
  final String title;
  final String notCheckedLabel;
  final String matchedLabel;
  final String divergedLabel;
  final String invalidLabel;
  final String rngNotCheckedLabel;
  final String rngMatchedLabel;
  final String rngMismatchedLabel;
  final String comparedOutcomesLabel;
  final String comparisonIndexLabel;
  final String caveatLabel;
  final String verifyLabel;
  final String actionErrorLabel;

  @override
  State<ReplayVerificationResultCard> createState() =>
      _ReplayVerificationResultCardState();
}

class _ReplayVerificationResultCardState
    extends State<ReplayVerificationResultCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant ReplayVerificationResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.checkedOutcomeCount != widget.checkedOutcomeCount ||
        oldWidget.rngStatus != widget.rngStatus ||
        oldWidget.rngMismatchCount != widget.rngMismatchCount ||
        oldWidget.divergenceIndex != widget.divergenceIndex ||
        oldWidget.summaryText != widget.summaryText ||
        oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _verifyAgain() async {
    final action = widget.onVerifyAgain;
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

  String get _statusLabel => switch (widget.status) {
    ReplayVerificationStatus.notChecked => widget.notCheckedLabel,
    ReplayVerificationStatus.matched => widget.matchedLabel,
    ReplayVerificationStatus.diverged => widget.divergedLabel,
    ReplayVerificationStatus.invalid => widget.invalidLabel,
  };

  IconData get _statusIcon => switch (widget.status) {
    ReplayVerificationStatus.notChecked => Icons.help_outline,
    ReplayVerificationStatus.matched => Icons.check_circle_outline,
    ReplayVerificationStatus.diverged => Icons.difference_outlined,
    ReplayVerificationStatus.invalid => Icons.gpp_bad_outlined,
  };

  String get _rngLabel => switch (widget.rngStatus) {
    ReplayRngCheckStatus.notChecked => widget.rngNotCheckedLabel,
    ReplayRngCheckStatus.matched => widget.rngMatchedLabel,
    ReplayRngCheckStatus.mismatched =>
      '${widget.rngMismatchedLabel}: ${widget.rngMismatchCount}',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon, color: NeonTheme.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(_statusLabel)),
                ),
              ],
            ),
            Text(
              '${widget.comparedOutcomesLabel}: ${widget.checkedOutcomeCount}',
            ),
            if (widget.divergenceIndex != null)
              Text('${widget.comparisonIndexLabel}: ${widget.divergenceIndex}'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.casino_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(_rngLabel)),
                ),
              ],
            ),
            if (widget.summaryText != null) Text(widget.summaryText!),
            Text(widget.caveatLabel),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onVerifyAgain != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('replayVerificationVerifyAgain'),
                label: widget.verifyLabel,
                width: double.infinity,
                loading: _running,
                onTap: _isBusy ? null : _verifyAgain,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
