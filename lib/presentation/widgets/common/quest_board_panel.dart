import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'empty_state_placeholder.dart';
import 'progress_bar_stars.dart';

/// One caller-supplied quest row — label/progress/target/claimed are
/// already resolved by the caller (typically read straight off
/// `DailyQuestService.progressOf`/`targetOf`/`isClaimed` for [id]); this
/// widget never talks to that service directly, same "pure/data-driven,
/// caller owns the source of truth" convention as [LeaderboardEntry].
class QuestViewModel {
  const QuestViewModel({
    required this.id,
    required this.label,
    required this.progress,
    required this.target,
    required this.claimed,
    this.claiming = false,
  });

  final String id;
  final String label;
  final int progress;
  final int target;
  final bool claimed;

  /// ENH-70: forwarded to this quest's own Claim `CommonButton.loading` —
  /// spinner + blocks double-tap while a caller-owned async claim (e.g. a
  /// server-validated claim) for THIS quest is in flight. `false` (default)
  /// unchanged from before this existed. Only the quest with `claiming:
  /// true` shows a spinner; every other quest in the same `QuestBoardPanel`
  /// is unaffected, since this lives on each quest's own view model rather
  /// than a single flag on the whole panel.
  final bool claiming;

  bool get isCompleted => progress >= target;

  /// Completed but not yet claimed — the only state in which the row's
  /// Claim button is enabled.
  bool get isClaimable => isCompleted && !claimed;
}

/// Displays a list of [QuestViewModel]s — progress bar + a Claim button
/// that's only enabled once a quest is completed and unclaimed — the
/// ready-to-use on-screen counterpart to `DailyQuestService` (IDEA-29),
/// which previously had no widget consuming it at all.
///
/// A quest whose [QuestViewModel.isClaimable] just turned true (this
/// build vs the previous one) pops its Claim button in with a small
/// celebratory bounce; a quest already claimable on first mount (e.g. the
/// panel is opened after progress was already earned in a previous
/// session) never animates, same "don't replay an already-earned moment"
/// convention as [ProgressBarStars]/`StarRating`.
class QuestBoardPanel extends StatelessWidget {
  const QuestBoardPanel({
    super.key,
    required this.quests,
    required this.onClaim,
  });

  final List<QuestViewModel> quests;

  /// Called with a quest's [QuestViewModel.id] when its Claim button is
  /// tapped. Only reachable while that quest [QuestViewModel.isClaimable].
  final void Function(String questId) onClaim;

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.assignment_turned_in_outlined,
        message: 'Không có nhiệm vụ nào hôm nay.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final quest in quests) ...[
          _QuestRow(quest: quest, onClaim: () => onClaim(quest.id)),
          if (quest != quests.last) const SizedBox(height: NeonTheme.s8),
        ],
      ],
    );
  }
}

class _QuestRow extends StatefulWidget {
  const _QuestRow({required this.quest, required this.onClaim});

  final QuestViewModel quest;
  final VoidCallback onClaim;

  @override
  State<_QuestRow> createState() => _QuestRowState();
}

class _QuestRowState extends State<_QuestRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _pop;

  @override
  void didUpdateWidget(covariant _QuestRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quest.isClaimable && !oldWidget.quest.isClaimable) {
      if (NeonTheme.reducedMotion(context)) return;
      (_pop ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ))
        ..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _pop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final fraction = quest.target == 0
        ? 1.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    Widget claimButton = CommonButton(
      label: quest.claimed ? 'Đã nhận' : 'Nhận thưởng',
      loading: quest.claiming,
      onTap: quest.isClaimable ? widget.onClaim : null,
      color: quest.isClaimable ? NeonTheme.gold : null,
    );
    final pop = _pop;
    if (pop != null) {
      claimButton = ScaleTransition(
        scale: CurvedAnimation(parent: pop, curve: Curves.easeOutBack),
        child: claimButton,
      );
    }

    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: quest.isClaimable
            ? Border.all(color: NeonTheme.gold, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            quest.label,
            style: TextStyle(
              color: NeonTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          ProgressBarStars(
            progress: fraction,
            starThresholds: const [],
            semanticLabel:
                '${quest.label}: ${quest.progress} of ${quest.target}',
          ),
          const SizedBox(height: NeonTheme.s16),
          claimButton,
        ],
      ),
    );
  }
}
