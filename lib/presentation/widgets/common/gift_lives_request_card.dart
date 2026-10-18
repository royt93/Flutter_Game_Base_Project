import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

enum GiftLivesRequestState { pending, sent, expired }

/// Caller-supplied life request; the widget never owns inventory or cooldowns.
@immutable
class GiftLivesRequest {
  const GiftLivesRequest({
    required this.requestId,
    required this.senderName,
    this.avatar,
    this.requestedAtText,
    this.state = GiftLivesRequestState.pending,
  });

  final String requestId;
  final String senderName;
  final Widget? avatar;
  final String? requestedAtText;
  final GiftLivesRequestState state;
}

/// One friend/clan "send me a life" row with a guarded Send action.
class GiftLivesRequestCard extends StatefulWidget {
  GiftLivesRequestCard({
    super.key,
    required this.request,
    required this.onSendLife,
    this.sendLabel = 'Send Life',
    this.sentLabel = 'Sent',
    this.expiredLabel = 'Expired',
    this.statusText,
    this.guardWindow = const Duration(milliseconds: 600),
  }) {
    if (request.requestId.trim().isEmpty || request.senderName.trim().isEmpty) {
      throw ArgumentError.value(
        request,
        'request',
        'requestId and senderName must not be empty',
      );
    }
    if (sendLabel.trim().isEmpty ||
        sentLabel.trim().isEmpty ||
        expiredLabel.trim().isEmpty) {
      throw ArgumentError('labels must not be empty');
    }
    if (guardWindow.isNegative) {
      throw ArgumentError.value(
        guardWindow,
        'guardWindow',
        'must not be negative',
      );
    }
  }

  final GiftLivesRequest request;
  final ValueChanged<String> onSendLife;
  final String sendLabel;
  final String sentLabel;
  final String expiredLabel;

  /// Caller-formatted cooldown/subtitle text (e.g. "Expires in 2h").
  final String? statusText;

  /// Taps inside this window after an accepted tap are dropped.
  final Duration guardWindow;

  @override
  State<GiftLivesRequestCard> createState() => _GiftLivesRequestCardState();
}

class _GiftLivesRequestCardState extends State<GiftLivesRequestCard> {
  final Stopwatch _guard = Stopwatch();
  Duration? _lastAccepted;

  void _send() {
    if (widget.request.state != GiftLivesRequestState.pending) return;
    if (!_guard.isRunning) _guard.start();
    final now = _guard.elapsed;
    if (_lastAccepted != null && now - _lastAccepted! < widget.guardWindow) {
      return;
    }
    _lastAccepted = now;
    widget.onSendLife(widget.request.requestId);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final enabled = request.state == GiftLivesRequestState.pending;
    final label = switch (request.state) {
      GiftLivesRequestState.pending => widget.sendLabel,
      GiftLivesRequestState.sent => widget.sentLabel,
      GiftLivesRequestState.expired => widget.expiredLabel,
    };
    final accent = switch (request.state) {
      GiftLivesRequestState.pending => NeonTheme.pink,
      GiftLivesRequestState.sent => NeonTheme.lime,
      GiftLivesRequestState.expired => NeonTheme.muted,
    };
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final subtitle = [
      if (request.requestedAtText != null) request.requestedAtText!,
      if (widget.statusText != null) widget.statusText!,
    ].join(' · ');

    return Semantics(
      container: true,
      label:
          '${request.senderName} asks for a life. ${enabled ? "Pending" : label}'
          '${subtitle.isEmpty ? "" : ". $subtitle"}',
      child: Container(
        key: ValueKey('giftLivesCard_${request.requestId}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 42,
                height: 42,
                child:
                    request.avatar ??
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
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              enabled: enabled,
              label: enabled ? '$label to ${request.senderName}' : label,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('giftLivesSend_${request.requestId}'),
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? _send : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: AnimatedContainer(
                      duration: duration,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? accent
                            : accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            enabled
                                ? Icons.favorite_rounded
                                : (request.state == GiftLivesRequestState.sent
                                      ? Icons.check_rounded
                                      : Icons.hourglass_disabled_rounded),
                            size: 14,
                            color: enabled ? Colors.white : NeonTheme.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: enabled ? Colors.white : NeonTheme.inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
