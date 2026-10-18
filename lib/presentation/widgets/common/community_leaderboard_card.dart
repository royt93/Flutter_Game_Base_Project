import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'empty_state_placeholder.dart';
import 'retry_error_state.dart';
import 'tiered_leaderboard_row.dart';

/// One caller-ordered community leaderboard entry.
@immutable
class CommunityLeaderboardEntry {
  const CommunityLeaderboardEntry({
    required this.id,
    required this.rank,
    required this.playerName,
    required this.score,
    this.zone = TierZone.safe,
    this.isCurrentPlayer = false,
    this.tier = LeaderboardTier.bronze,
    this.avatar,
  });

  final String id;
  final int rank;
  final String playerName;
  final String score;
  final TierZone zone;
  final bool isCurrentPlayer;
  final LeaderboardTier tier;
  final Widget? avatar;
}

/// Caller-ordered community leaderboard with optional current-player highlight.
///
/// Ordering, score formatting, tie-break and privacy rules belong to the caller.
class CommunityLeaderboardCard extends StatelessWidget {
  CommunityLeaderboardCard({
    super.key,
    required this.entries,
    this.onPlayerTap,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.title = 'Community Leaderboard',
    this.emptyMessage = 'No leaderboard entries yet.',
    this.semanticLabel,
    this.maxVisibleRows = 5,
  }) {
    if (title.trim().isEmpty || emptyMessage.trim().isEmpty) {
      throw ArgumentError('title and emptyMessage must not be empty');
    }
    if (maxVisibleRows <= 0) {
      throw ArgumentError.value(
        maxVisibleRows,
        'maxVisibleRows',
        'must be positive',
      );
    }
    final ids = <String>{};
    for (final entry in entries) {
      if (entry.id.trim().isEmpty ||
          entry.playerName.trim().isEmpty ||
          entry.score.trim().isEmpty) {
        throw ArgumentError.value(
          entry,
          'entries',
          'id, playerName and score must not be empty',
        );
      }
      if (entry.rank < 1) {
        throw ArgumentError.value(entry.rank, 'entry.rank', 'must be positive');
      }
      if (!ids.add(entry.id)) {
        throw ArgumentError.value(entry.id, 'entries', 'duplicate player id');
      }
    }
  }

  final List<CommunityLeaderboardEntry> entries;
  final ValueChanged<String>? onPlayerTap;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final String title;
  final String emptyMessage;
  final String? semanticLabel;
  final int maxVisibleRows;

  @override
  Widget build(BuildContext context) {
    final semantics = semanticLabel ?? '$title. ${entries.length} players.';
    return Semantics(
      key: const ValueKey('communityLeaderboardSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: NeonTheme.cyan.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 4, blur: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    key: const ValueKey('communityLeaderboardRefresh'),
                    tooltip: 'Refresh',
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh_rounded, color: NeonTheme.cyan),
                  ),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(NeonTheme.s16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              RetryErrorState(
                key: const ValueKey('communityLeaderboardError'),
                message: errorMessage!,
                onRetry: onRetry,
                compact: true,
              )
            else if (entries.isEmpty)
              EmptyStatePlaceholder(
                key: const ValueKey('communityLeaderboardEmpty'),
                icon: Icons.groups_rounded,
                message: emptyMessage,
                color: NeonTheme.cyan,
              )
            else
              SizedBox(
                height: maxVisibleRows * 64,
                child: ListView.builder(
                  key: const ValueKey('communityLeaderboardList'),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: TieredLeaderboardRow(
                        key: ValueKey('communityLeaderboard_${entry.id}'),
                        rank: entry.rank,
                        playerName: entry.playerName,
                        score: entry.score,
                        tier: entry.tier,
                        zone: entry.zone,
                        isCurrentPlayer: entry.isCurrentPlayer,
                        avatar: entry.avatar,
                        onTap: onPlayerTap == null
                            ? null
                            : () => onPlayerTap!(entry.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
