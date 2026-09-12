import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'avatar_frame.dart';

/// One caller-supplied leaderboard row — rank, name and score are already
/// formatted/localized strings (same convention as `VictoryCardTemplate`'s
/// `statLines`: this widget never invents ranking or number formatting).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    this.avatar,
    this.highlighted = false,
    this.onTap,
  });

  final int rank;
  final String name;
  final String score;

  /// Optional avatar slot, framed via [AvatarFrame]. Caller-supplied
  /// (image/icon/initials) — this widget doesn't fetch or manage avatars.
  final Widget? avatar;

  /// True for the row representing the current player — renders with an
  /// accent border so it stands out among opponents.
  final bool highlighted;

  /// Called when this row is tapped (e.g. to view that player's profile).
  /// When null, the row stays purely display-only (no press feedback).
  final VoidCallback? onTap;
}

/// Pure, data-driven leaderboard display (rank + name + score + optional
/// avatar), candy-styled to match the rest of `common/`. Composes
/// [AvatarFrame] for the avatar slot; ranking/scoring logic and data all
/// come from the consumer app.
class LeaderboardList extends StatelessWidget {
  const LeaderboardList({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in entries) ...[
          _LeaderboardRow(entry: entry),
          if (entry != entries.last) const SizedBox(height: NeonTheme.s8),
        ],
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final row = _row(context);
    // ENH-46: always wrap in PressableScale — with onTap null it's a no-op
    // (GestureDetector's callbacks stay null, AnimatedScale stays at 1.0),
    // identical to the prior display-only behavior. Semantics(button:
    // true) only added when actually tappable, so a screen reader doesn't
    // announce a non-interactive row as a button.
    final pressable = PressableScale(onTap: entry.onTap, child: row);
    return entry.onTap == null
        ? pressable
        : Semantics(button: true, child: pressable);
  }

  Widget _row(BuildContext context) {
    return Container(
      key: ValueKey('leaderboardRow_${entry.rank}'),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: entry.highlighted ? NeonTheme.cardAlt : NeonTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: entry.highlighted
            ? Border.all(color: NeonTheme.gold, width: 2)
            : null,
        boxShadow: NeonTheme.drop(y: 2, blur: 6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: NeonTheme.s16),
          if (entry.avatar != null) ...[
            AvatarFrame(size: 36, ringWidth: 2, child: entry.avatar!),
            const SizedBox(width: NeonTheme.s16),
          ],
          Expanded(
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: NeonTheme.s16),
          Text(
            entry.score,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
