import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/reward_transaction_pipeline.dart';
import 'common_button.dart';

const double _milestoneExtent = 164;

enum BattlePassTrack { free, vip }

enum BattlePassMilestoneStatus { locked, claimable, claimed }

class BattlePassMilestone {
  BattlePassMilestone({
    required this.id,
    required this.requiredProgress,
    required List<RewardLine> freeRewards,
    List<RewardLine> vipRewards = const [],
  }) : freeRewards = List.unmodifiable(freeRewards),
       vipRewards = List.unmodifiable(vipRewards) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (requiredProgress <= 0) {
      throw ArgumentError.value(
        requiredProgress,
        'requiredProgress',
        'must be non-negative',
      );
    }
    if (freeRewards.isEmpty) {
      throw ArgumentError.value(
        freeRewards,
        'freeRewards',
        'must not be empty',
      );
    }
  }

  final String id;
  final int requiredProgress;
  final List<RewardLine> freeRewards;
  final List<RewardLine> vipRewards;
}

class BattlePassMilestoneStatusView {
  const BattlePassMilestoneStatusView({
    required this.track,
    required this.status,
    required this.rewards,
  });

  final BattlePassTrack track;
  final BattlePassMilestoneStatus status;
  final List<RewardLine> rewards;
}

double milestoneProgressRatio({
  required int progress,
  required int previousThreshold,
  required int nextThreshold,
}) {
  if (previousThreshold < 0) {
    throw ArgumentError.value(
      previousThreshold,
      'previousThreshold',
      'must be non-negative',
    );
  }
  if (nextThreshold <= previousThreshold) {
    throw ArgumentError.value(
      nextThreshold,
      'nextThreshold',
      'must exceed previousThreshold',
    );
  }
  return ((progress - previousThreshold) / (nextThreshold - previousThreshold))
      .clamp(0.0, 1.0);
}

int currentBattlePassMilestoneIndex(
  List<BattlePassMilestone> milestones,
  int progress,
) {
  if (milestones.isEmpty) return 0;
  final index = milestones.indexWhere(
    (milestone) => milestone.requiredProgress >= progress,
  );
  return index == -1 ? milestones.length - 1 : index;
}

List<BattlePassMilestoneStatusView> battlePassMilestoneStatuses({
  required BattlePassMilestone milestone,
  required int progress,
  required bool vipEnabled,
  required Set<String> claimedFreeIds,
  required Set<String> claimedVipIds,
}) => [
  for (final track in BattlePassTrack.values)
    _statusForTrack(
      milestone: milestone,
      track: track,
      progress: progress,
      vipEnabled: vipEnabled,
      claimedIds: track == BattlePassTrack.free
          ? claimedFreeIds
          : claimedVipIds,
    ),
];

BattlePassMilestoneStatusView _statusForTrack({
  required BattlePassMilestone milestone,
  required BattlePassTrack track,
  required int progress,
  required bool vipEnabled,
  required Set<String> claimedIds,
}) {
  final rewards = track == BattlePassTrack.free
      ? milestone.freeRewards
      : milestone.vipRewards;
  final status = claimedIds.contains(milestone.id)
      ? BattlePassMilestoneStatus.claimed
      : rewards.isEmpty || (track == BattlePassTrack.vip && !vipEnabled)
      ? BattlePassMilestoneStatus.locked
      : progress >= milestone.requiredProgress
      ? BattlePassMilestoneStatus.claimable
      : BattlePassMilestoneStatus.locked;
  return BattlePassMilestoneStatusView(
    track: track,
    status: status,
    rewards: rewards,
  );
}

class BattlePassRoad extends StatefulWidget {
  const BattlePassRoad({
    super.key,
    required this.milestones,
    required this.progress,
    required this.vipEnabled,
    required this.claimedFreeIds,
    required this.claimedVipIds,
    required this.onClaimMilestone,
    this.physics,
    this.shrinkWrap = false,
  });

  final List<BattlePassMilestone> milestones;
  final int progress;
  final bool vipEnabled;
  final Set<String> claimedFreeIds;
  final Set<String> claimedVipIds;
  final void Function(String milestoneId, BattlePassTrack track)
  onClaimMilestone;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  State<BattlePassRoad> createState() => BattlePassRoadState();
}

class BattlePassRoadState extends State<BattlePassRoad> {
  late final ScrollController _scrollController;
  late int _currentIndex;
  static const _listKey = ValueKey('battlePassRoadList');

  @override
  void initState() {
    super.initState();
    _validateMilestones(widget.milestones);
    _currentIndex = currentBattlePassMilestoneIndex(
      widget.milestones,
      widget.progress,
    );
    _scrollController = ScrollController(
      initialScrollOffset: _currentIndex * _milestoneExtent,
    );
  }

  void _validateMilestones(List<BattlePassMilestone> milestones) {
    final ids = <String>{};
    var previous = -1;
    for (final milestone in milestones) {
      if (!ids.add(milestone.id)) {
        throw ArgumentError.value(
          milestone.id,
          'milestones',
          'ids must be unique',
        );
      }
      if (milestone.requiredProgress <= previous) {
        throw ArgumentError.value(
          milestone.requiredProgress,
          'milestones',
          'requiredProgress must be strictly increasing',
        );
      }
      previous = milestone.requiredProgress;
    }
  }

  @override
  void didUpdateWidget(covariant BattlePassRoad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.milestones, widget.milestones)) {
      _validateMilestones(widget.milestones);
    }
    final nextIndex = currentBattlePassMilestoneIndex(
      widget.milestones,
      widget.progress,
    );
    if (nextIndex != _currentIndex) {
      _currentIndex = nextIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (_currentIndex * _milestoneExtent).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.milestones.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      key: _listKey,
      controller: _scrollController,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemExtent: _milestoneExtent,
      itemCount: widget.milestones.length,
      itemBuilder: (context, index) {
        final milestone = widget.milestones[index];
        final previous = index == 0
            ? 0
            : widget.milestones[index - 1].requiredProgress;
        final segmentProgress = milestoneProgressRatio(
          progress: widget.progress,
          previousThreshold: previous,
          nextThreshold: milestone.requiredProgress,
        );
        final statuses = battlePassMilestoneStatuses(
          milestone: milestone,
          progress: widget.progress,
          vipEnabled: widget.vipEnabled,
          claimedFreeIds: widget.claimedFreeIds,
          claimedVipIds: widget.claimedVipIds,
        );
        return Row(
          key: ValueKey('battlePassMilestone_${milestone.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: CustomPaint(
                painter: _MilestoneRailPainter(
                  progress: segmentProgress,
                  isLast: index == widget.milestones.length - 1,
                ),
                child: Center(
                  child: Semantics(
                    label: 'Milestone ${index + 1}',
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.progress >= milestone.requiredProgress
                            ? NeonTheme.gold
                            : NeonTheme.cardAlt,
                        border: Border.all(color: NeonTheme.inkSoft, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milestone ${index + 1} · ${milestone.requiredProgress}',
                      key: ValueKey('battlePassMilestoneLabel_${milestone.id}'),
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s8),
                    Expanded(
                      child: Row(
                        children: [
                          for (final status in statuses)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  end: status.track == BattlePassTrack.free
                                      ? NeonTheme.s8
                                      : 0,
                                ),
                                child: _RewardTrackCard(
                                  key: ValueKey(
                                    'battlePassTrack_${milestone.id}_${status.track.name}',
                                  ),
                                  milestone: milestone,
                                  view: status,
                                  onClaim: () => widget.onClaimMilestone(
                                    milestone.id,
                                    status.track,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RewardTrackCard extends StatelessWidget {
  const _RewardTrackCard({
    super.key,
    required this.milestone,
    required this.view,
    required this.onClaim,
  });

  final BattlePassMilestone milestone;
  final BattlePassMilestoneStatusView view;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final available = view.status == BattlePassMilestoneStatus.claimable;
    final claimed = view.status == BattlePassMilestoneStatus.claimed;
    final trackName = view.track == BattlePassTrack.free ? 'Free' : 'VIP';
    final rewardText = view.rewards.isEmpty
        ? '—'
        : view.rewards
              .map((reward) => '+${reward.amount} ${reward.currency}')
              .join('\n');
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: available ? NeonTheme.gold : NeonTheme.cardAlt,
          width: available ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$trackName · $rewardText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
          ),
          const Spacer(),
          if (available)
            CommonButton(
              key: ValueKey(
                'battlePassClaim_${milestone.id}_${view.track.name}',
              ),
              label: 'Claim $trackName',
              onTap: onClaim,
              color: NeonTheme.gold,
            )
          else
            Text(
              key: ValueKey(
                'battlePassState_${milestone.id}_${view.track.name}',
              ),
              claimed
                  ? 'Claimed'
                  : view.status == BattlePassMilestoneStatus.locked &&
                        view.track == BattlePassTrack.vip &&
                        view.rewards.isNotEmpty
                  ? 'VIP locked'
                  : 'Locked',
              textAlign: TextAlign.center,
              style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _MilestoneRailPainter extends CustomPainter {
  const _MilestoneRailPainter({required this.progress, required this.isLast});

  final double progress;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 18.0;
    final mid = size.height / 2;
    final base = Paint()
      ..color = NeonTheme.cardAlt
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = NeonTheme.gold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (mid > 0) {
      canvas.drawLine(Offset(x, 0), Offset(x, mid), base);
      if (progress > 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, mid * progress), active);
      }
    }
    if (!isLast && mid < size.height) {
      canvas.drawLine(Offset(x, mid), Offset(x, size.height), base);
    }
  }

  @override
  bool shouldRepaint(covariant _MilestoneRailPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isLast != isLast;
}
