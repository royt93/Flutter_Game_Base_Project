import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'badge_dot.dart';

class ClanChatPreviewBar extends StatelessWidget {
  ClanChatPreviewBar({
    super.key,
    required this.onTap,
    this.senderName,
    this.senderAvatar,
    this.message,
    this.timestampText,
    this.unreadCount = 0,
    this.emptyMessage = 'No messages yet',
    this.semanticLabel = 'Clan chat',
  }) {
    if (unreadCount < 0) {
      throw ArgumentError.value(unreadCount, 'unreadCount', 'must be >= 0');
    }
    if ((message == null) != (senderName == null) ||
        (message != null && message!.trim().isEmpty) ||
        (senderName != null && senderName!.trim().isEmpty)) {
      throw ArgumentError(
        'message and senderName must both be nonblank or null',
      );
    }
    if (emptyMessage.trim().isEmpty || semanticLabel.trim().isEmpty) {
      throw ArgumentError('emptyMessage and semanticLabel must not be blank');
    }
  }

  final VoidCallback onTap;
  final String? senderName;
  final Widget? senderAvatar;
  final String? message;
  final String? timestampText;
  final int unreadCount;
  final String emptyMessage;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final summary = message == null
        ? emptyMessage
        : '$senderName: $message${timestampText == null ? '' : ', $timestampText'}';
    return Semantics(
      button: true,
      label: '$semanticLabel, $summary, $unreadCount unread',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('clanChatPreviewTap'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NeonTheme.purple.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 36,
                    child: message != null && senderAvatar != null
                        ? senderAvatar
                        : ColoredBox(
                            color: NeonTheme.cardAlt,
                            child: Icon(
                              Icons.chat_bubble_rounded,
                              color: NeonTheme.purple,
                              size: 22,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              senderName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: NeonTheme.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (timestampText != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                timestampText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: NeonTheme.inkSoft,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    Text(
                      message ?? emptyMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                const BadgeDot(size: 8, pulse: true),
                const SizedBox(width: 6),
                Container(
                  key: const ValueKey('clanChatUnreadBadge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.pink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
