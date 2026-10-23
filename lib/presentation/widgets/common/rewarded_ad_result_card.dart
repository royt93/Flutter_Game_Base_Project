import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum RewardedAdStatus { idle, notReady, loading, rewarded, cancelled, failed }

/// Rewarded-ad state and watch button. It never calls `AdRewardSeam` and never
/// grants anything. The caller maps `isReady` and the `showRewardedAd` result
/// to [status] and grants the reward once, with its own idempotent
/// transaction id, only after the seam returned `true`. The "rewarded" copy
/// is shown only when the caller sets [RewardedAdStatus.rewarded].
class RewardedAdResultCard extends StatefulWidget {
  RewardedAdResultCard({
    super.key,
    required this.status,
    required this.onWatch,
    this.rewardText,
    this.busy = false,
    this.title = 'Watch an ad',
    this.idleLabel = 'Watch an ad to earn a reward',
    this.notReadyLabel = 'No ad is ready yet. Try again soon.',
    this.loadingLabel = 'Loading ad',
    this.rewardedLabel = 'Reward earned',
    this.cancelledLabel = 'Ad closed early. No reward earned.',
    this.failedLabel = 'The ad could not be shown. No reward earned.',
    this.watchLabel = 'Watch ad',
    this.retryLabel = 'Try again',
    this.actionErrorLabel = 'Action failed. Try again.',
  }) {
    for (final (name, value) in [
      ('title', title),
      ('idleLabel', idleLabel),
      ('notReadyLabel', notReadyLabel),
      ('loadingLabel', loadingLabel),
      ('rewardedLabel', rewardedLabel),
      ('cancelledLabel', cancelledLabel),
      ('failedLabel', failedLabel),
      ('watchLabel', watchLabel),
      ('retryLabel', retryLabel),
      ('actionErrorLabel', actionErrorLabel),
      ('rewardText', rewardText),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final RewardedAdStatus status;
  final Future<void> Function() onWatch;
  final String? rewardText;
  final bool busy;
  final String title;
  final String idleLabel;
  final String notReadyLabel;
  final String loadingLabel;
  final String rewardedLabel;
  final String cancelledLabel;
  final String failedLabel;
  final String watchLabel;
  final String retryLabel;
  final String actionErrorLabel;

  @override
  State<RewardedAdResultCard> createState() => _RewardedAdResultCardState();
}

class _RewardedAdResultCardState extends State<RewardedAdResultCard> {
  bool _running = false;
  bool _failed = false;
  int _generation = 0;

  bool get _isBusy =>
      widget.busy || _running || widget.status == RewardedAdStatus.loading;

  bool get _canWatch => switch (widget.status) {
    RewardedAdStatus.idle ||
    RewardedAdStatus.cancelled ||
    RewardedAdStatus.failed => true,
    _ => false,
  };

  @override
  void didUpdateWidget(covariant RewardedAdResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.busy != widget.busy) {
      _generation++;
      _failed = false;
    }
  }

  Future<void> _watch() async {
    if (_isBusy || !_canWatch) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onWatch();
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
    RewardedAdStatus.idle => widget.idleLabel,
    RewardedAdStatus.notReady => widget.notReadyLabel,
    RewardedAdStatus.loading => widget.loadingLabel,
    RewardedAdStatus.rewarded => widget.rewardedLabel,
    RewardedAdStatus.cancelled => widget.cancelledLabel,
    RewardedAdStatus.failed => widget.failedLabel,
  };

  IconData get _icon => switch (widget.status) {
    RewardedAdStatus.idle => Icons.ondemand_video_outlined,
    RewardedAdStatus.notReady => Icons.hourglass_empty,
    RewardedAdStatus.loading => Icons.downloading_outlined,
    RewardedAdStatus.rewarded => Icons.card_giftcard,
    RewardedAdStatus.cancelled => Icons.cancel_outlined,
    RewardedAdStatus.failed => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final retry =
        widget.status == RewardedAdStatus.cancelled ||
        widget.status == RewardedAdStatus.failed;
    return Semantics(
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
              if (widget.status == RewardedAdStatus.rewarded &&
                  widget.rewardText != null)
                Text(widget.rewardText!),
              if (_failed) Text(widget.actionErrorLabel),
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('rewardedAdWatch'),
                label: retry ? widget.retryLabel : widget.watchLabel,
                width: double.infinity,
                loading: _isBusy,
                onTap: _isBusy || !_canWatch ? null : _watch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
