import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/neon_theme.dart';
import '../../../core/storage_service.dart';
import 'common_button.dart';

enum FriendRequestAction { accept, decline }

@immutable
class FriendRequestItem {
  FriendRequestItem({
    required this.requestId,
    required this.name,
    this.avatar,
    this.subtitle,
    this.mutualFriendsCount = 0,
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be blank');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    if (mutualFriendsCount < 0) {
      throw ArgumentError.value(
        mutualFriendsCount,
        'mutualFriendsCount',
        'must be >= 0',
      );
    }
  }

  final String requestId;
  final String name;
  final Widget? avatar;
  final String? subtitle;
  final int mutualFriendsCount;
}

class FriendRequestTile extends StatelessWidget {
  FriendRequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.busyAction,
    this.acceptLabel = 'Accept',
    this.declineLabel = 'Decline',
    this.mutualFriendsText,
  }) {
    if (acceptLabel.trim().isEmpty || declineLabel.trim().isEmpty) {
      throw ArgumentError('action labels must not be blank');
    }
  }

  final FriendRequestItem request;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;
  final FriendRequestAction? busyAction;
  final String acceptLabel;
  final String declineLabel;
  final String? mutualFriendsText;

  void _act(FriendRequestAction action) {
    if (busyAction != null) return;
    if (StorageService.maybe != null) fireHaptic(HapticLevel.light);
    (action == FriendRequestAction.accept ? onAccept : onDecline)(
      request.requestId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mutual =
        mutualFriendsText ??
        '${request.mutualFriendsCount} mutual ${request.mutualFriendsCount == 1 ? 'friend' : 'friends'}';
    final stackActions = MediaQuery.textScalerOf(context).scale(19) > 25;
    Widget button(FriendRequestAction action) {
      final accepting = action == FriendRequestAction.accept;
      final label = accepting ? acceptLabel : declineLabel;
      return CommonButton(
        key: ValueKey('friendRequest_${action.name}_${request.requestId}'),
        label: label,
        semanticLabel: '$label ${request.name}',
        variant: accepting
            ? CommonButtonVariant.primary
            : CommonButtonVariant.secondary,
        color: accepting ? NeonTheme.purple : NeonTheme.inkSoft,
        width: double.infinity,
        loading: busyAction == action,
        onTap: busyAction == null || busyAction == action
            ? () => _act(action)
            : null,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeonTheme.purple.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 44,
                    child:
                        request.avatar ??
                        ColoredBox(
                          color: NeonTheme.cardAlt,
                          child: Icon(
                            Icons.person_rounded,
                            color: NeonTheme.inkSoft,
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
                    Text(
                      request.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (request.subtitle != null)
                      Text(
                        request.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      mutual,
                      style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stackActions) ...[
            button(FriendRequestAction.accept),
            const SizedBox(height: 8),
            button(FriendRequestAction.decline),
          ] else
            Row(
              children: [
                Expanded(child: button(FriendRequestAction.accept)),
                const SizedBox(width: 8),
                Expanded(child: button(FriendRequestAction.decline)),
              ],
            ),
        ],
      ),
    );
  }
}
