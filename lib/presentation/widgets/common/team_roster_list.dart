import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// Role of a team or clan member.
enum TeamRole { leader, elder, member }

/// Caller-supplied member item presentation model.
@immutable
class TeamMemberItem {
  const TeamMemberItem({
    required this.id,
    required this.name,
    required this.role,
    this.avatar,
    this.trophies = 0,
    this.isOnline = false,
    this.lastSeenText,
    this.isSelf = false,
  });

  final String id;
  final String name;
  final TeamRole role;
  final Widget? avatar;
  final int trophies;
  final bool isOnline;
  final String? lastSeenText;
  final bool isSelf;
}

/// Lazy list of clan or team members with caller-owned promote/kick actions
/// and capacity counting.
class TeamRosterList extends StatelessWidget {
  TeamRosterList({
    super.key,
    required this.members,
    required this.onMemberTap,
    this.onPromote,
    this.onKick,
    this.maxMembers,
    this.title = 'Team Members',
    this.emptyMessage = 'No members in this team.',
    this.maxListHeight = 420,
    this.expand = false,
  }) {
    if (title.trim().isEmpty || emptyMessage.trim().isEmpty) {
      throw ArgumentError('title and emptyMessage must not be empty');
    }
    if (!maxListHeight.isFinite || maxListHeight <= 0) {
      throw ArgumentError.value(
        maxListHeight,
        'maxListHeight',
        'must be positive and finite',
      );
    }
    if (maxMembers != null) {
      if (maxMembers! <= 0) {
        throw ArgumentError.value(maxMembers, 'maxMembers', 'must be positive');
      }
      if (maxMembers! < members.length) {
        throw ArgumentError.value(
          maxMembers,
          'maxMembers',
          'cannot be less than current member count',
        );
      }
    }
    final ids = <String>{};
    for (final member in members) {
      if (member.id.trim().isEmpty || member.name.trim().isEmpty) {
        throw ArgumentError.value(
          member,
          'members',
          'id and name must not be empty',
        );
      }
      if (member.trophies < 0) {
        throw ArgumentError.value(
          member.trophies,
          'members',
          'trophies must be non-negative',
        );
      }
      if (!ids.add(member.id)) {
        throw ArgumentError.value(member.id, 'members', 'duplicate member id');
      }
    }
  }

  final List<TeamMemberItem> members;
  final ValueChanged<String> onMemberTap;
  final ValueChanged<String>? onPromote;
  final ValueChanged<String>? onKick;
  final int? maxMembers;
  final String title;
  final String emptyMessage;
  final double maxListHeight;

  /// Fills the parent's remaining height instead of fitting content. Needs a
  /// bounded-height parent (e.g. inside an `Expanded`); ignores [maxListHeight].
  final bool expand;

  Color _roleColor(TeamRole role) => switch (role) {
    TeamRole.leader => NeonTheme.gold,
    TeamRole.elder => NeonTheme.purple,
    TeamRole.member => NeonTheme.muted,
  };

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final countText = maxMembers != null
        ? '${members.length}/$maxMembers'
        : '${members.length}';
    final semantics =
        '$title. $countText members. ${members.where((m) => m.isOnline).length} online.';

    // Base row height ~68dp, scaled with textScale.
    final hasActions = onPromote != null || onKick != null;
    final rowExtent =
        (68.0 * textScale * (hasActions && textScale > 1 ? 1.5 : 1)).clamp(
          64.0,
          240.0,
        );
    final totalHeight = members.isEmpty
        ? 120.0
        : (members.length * rowExtent + (members.length - 1) * 8.0);
    final listHeight = totalHeight.clamp(0.0, maxListHeight);

    return Semantics(
      key: const ValueKey('teamRosterSemantics'),
      container: true,
      label: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NeonTheme.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NeonTheme.inkSoft.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    color: NeonTheme.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          if (members.isEmpty)
            expand
                ? Expanded(
                    child: Center(
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NeonTheme.inkSoft),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NeonTheme.inkSoft),
                      ),
                    ),
                  )
          else if (expand)
            Expanded(
              child: ListView.separated(
                key: const ValueKey('teamRosterListView'),
                padding: EdgeInsets.zero,
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => SizedBox(
                  height: rowExtent,
                  child: _memberTile(context, members[index]),
                ),
              ),
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                key: const ValueKey('teamRosterListView'),
                padding: EdgeInsets.zero,
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => SizedBox(
                  height: rowExtent,
                  child: _memberTile(context, members[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberTile(BuildContext context, TeamMemberItem member) {
    final roleColor = _roleColor(member.role);
    final statusLabel = member.isOnline
        ? 'online'
        : (member.lastSeenText ?? 'offline');
    final tileSemantics =
        '${member.name}, ${member.role.name}, $statusLabel, ${fmtNum(member.trophies)} trophies${member.isSelf ? ", you" : ""}';

    return Semantics(
      button: true,
      label: tileSemantics,
      child: GestureDetector(
        key: ValueKey('teamMemberTile_${member.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onMemberTap(member.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: member.isSelf
                ? NeonTheme.cyan.withValues(alpha: 0.08)
                : NeonTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: member.isSelf
                  ? NeonTheme.cyan
                  : NeonTheme.inkSoft.withValues(alpha: 0.18),
              width: member.isSelf ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child:
                          member.avatar ??
                          Container(
                            color: NeonTheme.cardAlt,
                            child: Icon(
                              Icons.person_rounded,
                              color: NeonTheme.inkSoft,
                              size: 26,
                            ),
                          ),
                    ),
                  ),
                  PositionedDirectional(
                    end: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: member.isOnline
                            ? NeonTheme.lime
                            : NeonTheme.muted,
                        shape: BoxShape.circle,
                        border: Border.all(color: NeonTheme.card, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (member.isSelf) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: NeonTheme.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                color: NeonTheme.cyan,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: roleColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            member.role.name.toUpperCase(),
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          member.isOnline
                              ? 'Online'
                              : (member.lastSeenText ?? 'Offline'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: member.isOnline
                                ? NeonTheme.lime
                                : NeonTheme.inkSoft,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: NeonTheme.gold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    fmtNum(member.trophies),
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (!member.isSelf && (onPromote != null || onKick != null)) ...[
                const SizedBox(width: 2),
                if (onPromote != null && member.role != TeamRole.leader)
                  Semantics(
                    button: true,
                    label: 'Promote ${member.name}',
                    child: GestureDetector(
                      key: ValueKey('teamMemberPromote_${member.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPromote!(member.id),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: NeonTheme.purple.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: NeonTheme.purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onKick != null && member.role != TeamRole.leader)
                  Semantics(
                    button: true,
                    label: 'Kick ${member.name}',
                    child: GestureDetector(
                      key: ValueKey('teamMemberKick_${member.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onKick!(member.id),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
