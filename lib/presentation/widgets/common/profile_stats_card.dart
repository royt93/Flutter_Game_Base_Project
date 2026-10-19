import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'avatar_frame.dart';
import 'xp_level_header.dart';

/// One caller-formatted profile statistic.
@immutable
class ProfileStat {
  ProfileStat({required this.label, required this.valueText, this.icon}) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (valueText.trim().isEmpty) {
      throw ArgumentError.value(valueText, 'valueText', 'must not be blank');
    }
  }

  final String label;
  final String valueText;
  final IconData? icon;
}

/// Player profile summary: avatar/frame, identity, optional level and caller-
/// formatted stats. It stores no profile state and owns no external actions.
class ProfileStatsCard extends StatelessWidget {
  ProfileStatsCard({
    super.key,
    required this.name,
    required this.avatar,
    this.frameColor,
    this.title,
    this.level,
    this.stats = const <ProfileStat>[],
    this.onTap,
    this.onEditAvatar,
    this.editAvatarLabel = 'Edit avatar',
    this.semanticLabel,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    if (stats.length > 4) {
      throw ArgumentError.value(
        stats.length,
        'stats',
        'must contain at most 4',
      );
    }
    final ids = stats.map((s) => s.label).toSet();
    if (ids.length != stats.length) {
      throw ArgumentError.value(stats, 'stats', 'labels must be unique');
    }
    if (editAvatarLabel.trim().isEmpty) {
      throw ArgumentError.value(
        editAvatarLabel,
        'editAvatarLabel',
        'must not be blank',
      );
    }
    for (final (field, value) in [
      ('title', title),
      ('semanticLabel', semanticLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, field, 'must not be blank');
      }
    }
    final currentLevel = level;
    if (currentLevel != null) {
      if (currentLevel.level < 1) {
        throw ArgumentError.value(currentLevel, 'level', 'must be >= 1');
      }
      if (currentLevel.currentXp < 0) {
        throw ArgumentError.value(
          currentLevel.currentXp,
          'level.currentXp',
          'must be >= 0',
        );
      }
      final next = currentLevel.xpForNextLevel;
      if (next != null && (next <= 0 || currentLevel.currentXp > next)) {
        throw ArgumentError.value(
          next,
          'level.xpForNextLevel',
          'must be > 0 and >= currentXp',
        );
      }
    }
  }

  final String name;
  final Widget avatar;
  final Color? frameColor;
  final String? title;
  final ProfileLevel? level;
  final List<ProfileStat> stats;
  final VoidCallback? onTap;
  final VoidCallback? onEditAvatar;
  final String editAvatarLabel;

  /// Replaces the default English card description (caller owns i18n).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final nameAndTitle = [name, ?title].join(', ');
    final statsText = stats.map((s) => '${s.label} ${s.valueText}').join(', ');
    final spoken =
        semanticLabel ??
        '$nameAndTitle${level == null ? '' : ', level ${level!.level}'}'
            '${statsText.isEmpty ? '' : ', $statsText'}';

    final avatarView = Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarFrame(
          color: frameColor,
          size: 64,
          semanticLabel: '$name avatar',
          child: avatar,
        ),
        if (onEditAvatar != null)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: editAvatarLabel,
              onTap: onEditAvatar,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('profileStatsEditAvatar'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: onEditAvatar,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: NeonTheme.cyan,
                    shape: BoxShape.circle,
                    border: Border.all(color: NeonTheme.card, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: NeonTheme.ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (title != null)
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NeonTheme.purple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (level != null) ...[
          const SizedBox(height: 6),
          XpLevelHeader(
            level: level!.level,
            currentXp: level!.currentXp,
            xpForNextLevel: level!.xpForNextLevel,
            title: level!.label,
            xpText: level!.xpText,
          ),
        ],
      ],
    );
    final header = textScale > 1.3
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [avatarView, const SizedBox(height: 12), info],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatarView,
              const SizedBox(width: 8),
              Expanded(child: info),
            ],
          );

    final children = <Widget>[
      header,
      if (stats.isNotEmpty) ...[
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final columns = constraints.maxWidth < 320 * textScale ? 1 : 2;
            return GridView.builder(
              key: const ValueKey('profileStatsGrid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 52 * textScale,
              ),
              itemBuilder: (context, index) => _statTile(stats[index]),
            );
          },
        ),
      ],
    ];

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NeonTheme.purple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );

    final interactive = onTap == null
        ? Semantics(label: spoken, child: card)
        : Semantics(
            button: true,
            label: spoken,
            onTap: onTap,
            child: PressableScale(onTap: onTap, child: card),
          );
    if (onTap != null) return interactive;
    return Semantics(label: spoken, excludeSemantics: true, child: card);
  }

  Widget _statTile(ProfileStat stat) => Container(
    key: ValueKey('profileStat_${stat.label}'),
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: NeonTheme.cardAlt,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (stat.icon != null) ...[
          ExcludeSemantics(
            child: Icon(stat.icon, size: 18, color: NeonTheme.purple),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                stat.valueText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Caller-supplied progression data; no service lookup or XP calculation.
@immutable
class ProfileLevel {
  ProfileLevel({
    required this.level,
    required this.currentXp,
    this.xpForNextLevel,
    this.label,
    this.xpText,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be >= 1');
    }
    if (currentXp < 0) {
      throw ArgumentError.value(currentXp, 'currentXp', 'must be >= 0');
    }
    final next = xpForNextLevel;
    if (next != null && (next <= 0 || currentXp > next)) {
      throw ArgumentError.value(
        next,
        'xpForNextLevel',
        'must be > 0 and >= currentXp',
      );
    }
    for (final (name, value) in [('label', label), ('xpText', xpText)]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final int level;
  final int currentXp;
  final int? xpForNextLevel;
  final String? label;
  final String? xpText;
}
