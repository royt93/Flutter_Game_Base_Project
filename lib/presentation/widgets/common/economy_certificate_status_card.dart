import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum EconomyCertificateCardStatus {
  unverified,
  valid,
  tampered,
  clockSuspicious,
}

/// Verification result only. It never accepts balances, certificate JSON,
/// signatures or secrets; the caller maps `EconomyCertificateVerification`
/// to [status] and supplies any safe summary text.
class EconomyCertificateStatusCard extends StatefulWidget {
  EconomyCertificateStatusCard({
    super.key,
    required this.status,
    this.summaryText,
    this.onVerifyAgain,
    this.busy = false,
    this.title = 'Economy certificate',
    this.unverifiedLabel = 'Not checked yet',
    this.validLabel = 'Signature checks out',
    this.tamperedLabel = 'Could not be verified',
    this.clockSuspiciousLabel =
        'Signature checks out, but the device clock looked altered when it was issued',
    this.verifyLabel = 'Verify again',
    this.actionErrorLabel = 'Verification failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('unverifiedLabel', unverifiedLabel),
      ('validLabel', validLabel),
      ('tamperedLabel', tamperedLabel),
      ('clockSuspiciousLabel', clockSuspiciousLabel),
      ('verifyLabel', verifyLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('summaryText', summaryText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final EconomyCertificateCardStatus status;
  final String? summaryText;
  final Future<void> Function()? onVerifyAgain;
  final bool busy;
  final String title;
  final String unverifiedLabel;
  final String validLabel;
  final String tamperedLabel;
  final String clockSuspiciousLabel;
  final String verifyLabel;
  final String actionErrorLabel;

  @override
  State<EconomyCertificateStatusCard> createState() =>
      _EconomyCertificateStatusCardState();
}

class _EconomyCertificateStatusCardState
    extends State<EconomyCertificateStatusCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy => widget.busy || _running;

  @override
  void didUpdateWidget(covariant EconomyCertificateStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _verify() async {
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

  String get _label => switch (widget.status) {
    EconomyCertificateCardStatus.unverified => widget.unverifiedLabel,
    EconomyCertificateCardStatus.valid => widget.validLabel,
    EconomyCertificateCardStatus.tampered => widget.tamperedLabel,
    EconomyCertificateCardStatus.clockSuspicious => widget.clockSuspiciousLabel,
  };

  IconData get _icon => switch (widget.status) {
    EconomyCertificateCardStatus.unverified => Icons.help_outline,
    EconomyCertificateCardStatus.valid => Icons.verified_outlined,
    EconomyCertificateCardStatus.tampered => Icons.gpp_bad_outlined,
    EconomyCertificateCardStatus.clockSuspicious => Icons.schedule,
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
                Icon(_icon, color: NeonTheme.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(_label)),
                ),
              ],
            ),
            if (widget.summaryText != null) Text(widget.summaryText!),
            if (_failed) Text(widget.actionErrorLabel),
            if (widget.onVerifyAgain != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('economyCertificateVerify'),
                label: widget.verifyLabel,
                width: double.infinity,
                loading: _running,
                onTap: _isBusy ? null : _verify,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
