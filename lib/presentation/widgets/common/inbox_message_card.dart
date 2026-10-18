import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import 'common_button.dart';

/// One reward attached to an inbox message (presentation-only).
@immutable
class InboxAttachment {
  const InboxAttachment({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final int amount;
}

/// Presentation-only system/event mail card (FEAT-146): unread badge,
/// attachments, self-ticking expiry countdown and a Claim action.
///
/// The caller owns read/claimed state and reward granting; this widget only
/// reports taps through [onOpen] and [onClaim].
class InboxMessageCard extends StatefulWidget {
  InboxMessageCard({
    super.key,
    required this.title,
    required this.body,
    this.receivedLabel,
    this.isRead = false,
    this.isClaimed = false,
    this.attachments = const [],
    this.expiresAt,
    this.onOpen,
    this.onClaim,
    this.claimLabel = 'Claim',
    this.semanticLabel,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be empty');
    }
    if (claimLabel.trim().isEmpty) {
      throw ArgumentError.value(claimLabel, 'claimLabel', 'must not be empty');
    }
    for (final a in attachments) {
      if (a.amount < 0) {
        throw ArgumentError.value(
          a.amount,
          'attachments',
          'amount must be non-negative',
        );
      }
    }
  }

  final String title;
  final String body;
  final String? receivedLabel;
  final bool isRead;
  final bool isClaimed;
  final List<InboxAttachment> attachments;
  final DateTime? expiresAt;
  final VoidCallback? onOpen;
  final VoidCallback? onClaim;
  final String claimLabel;
  final String? semanticLabel;
  final DateTime Function() clock;

  @override
  State<InboxMessageCard> createState() => _InboxMessageCardState();
}

class _InboxMessageCardState extends State<InboxMessageCard> {
  Timer? _timer;
  late Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _syncTimer();
  }

  @override
  void didUpdateWidget(InboxMessageCard old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) {
      _remaining = _computeRemaining();
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration? _computeRemaining() {
    final e = widget.expiresAt;
    return e?.difference(widget.clock());
  }

  bool get _expired => _remaining != null && _remaining! <= Duration.zero;

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (_remaining == null || _expired) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _computeRemaining();
      if (!mounted) return;
      setState(() => _remaining = next);
      if (_expired) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  bool get _canClaim =>
      widget.onClaim != null &&
      !widget.isClaimed &&
      !_expired &&
      widget.attachments.isNotEmpty;

  String? get _expiryText {
    if (_remaining == null) return null;
    if (_expired) return 'Expired';
    return 'Expires in ${fmtDurDays(_remaining!)}';
  }

  @override
  Widget build(BuildContext context) {
    final expiry = _expiryText;
    final unread = !widget.isRead;
    final accent = _expired ? NeonTheme.muted : NeonTheme.cyan;

    final label =
        widget.semanticLabel ??
        '${unread ? "Unread. " : ""}${widget.title}. ${widget.body}'
            '${widget.attachments.isEmpty ? "" : " ${widget.attachments.length} attachments."}'
            '${expiry == null ? "" : " $expiry."}';

    return Semantics(
      key: const ValueKey('inboxMessageCardSemantics'),
      container: true,
      label: label,
      child: GestureDetector(
        key: const ValueKey('inboxMessageCardTap'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.all(NeonTheme.s16),
          decoration: BoxDecoration(
            color: unread ? NeonTheme.card : NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: unread ? 0.6 : 0.25),
              width: unread ? 2 : 1,
            ),
            boxShadow: NeonTheme.drop(y: 3, blur: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unread)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 5,
                        end: NeonTheme.s8,
                      ),
                      child: Container(
                        key: const ValueKey('inboxUnreadBadge'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: NeonTheme.red,
                          shape: BoxShape.circle,
                          boxShadow: NeonTheme.glow(NeonTheme.red, blur: 6),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: NeonTheme.ink,
                          ),
                        ),
                        if (widget.receivedLabel != null)
                          Text(
                            widget.receivedLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NeonTheme.inkSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NeonTheme.s8),
              Text(
                widget.body,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: NeonTheme.inkSoft,
                ),
              ),
              if (widget.attachments.isNotEmpty) ...[
                const SizedBox(height: NeonTheme.s8),
                Wrap(
                  spacing: NeonTheme.s8,
                  runSpacing: 6,
                  children: widget.attachments.map(_chip).toList(),
                ),
              ],
              if (expiry != null || widget.onClaim != null) ...[
                const SizedBox(height: NeonTheme.s8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    if (expiry != null)
                      Text(
                        expiry,
                        key: const ValueKey('inboxExpiryLabel'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _expired ? NeonTheme.red : NeonTheme.orange,
                        ),
                      ),
                    if (widget.onClaim != null)
                      CommonButton(
                        key: const ValueKey('inboxClaimBtn'),
                        label: widget.isClaimed ? 'Claimed' : widget.claimLabel,
                        width: 120,
                        onTap: _canClaim ? widget.onClaim : null,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(InboxAttachment a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeonTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeonTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(a.icon, size: 14, color: NeonTheme.gold),
          const SizedBox(width: 4),
          Text(
            '${a.label} x${fmtNum(a.amount)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NeonTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
