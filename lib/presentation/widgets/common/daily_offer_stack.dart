import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

/// Data for one daily/live-ops offer (presentation-only).
@immutable
class DailyOffer {
  const DailyOffer({
    required this.id,
    required this.title,
    required this.priceLabel,
    this.subtitle,
    this.badgeLabel,
    this.icon = Icons.local_offer_rounded,
    this.isExpired = false,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String? subtitle;
  final String? badgeLabel;
  final IconData icon;
  final bool isExpired;
}

/// Caller-ordered stack of daily/live-ops offers.
///
/// The caller owns offer ranking, expiry evaluation and purchase flow. This
/// widget only displays the provided order and routes taps by offer id.
class DailyOfferStack extends StatelessWidget {
  DailyOfferStack({
    super.key,
    required this.offers,
    required this.onOpen,
    this.title = 'Daily Offers',
    this.emptyMessage = 'No offers available right now.',
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (emptyMessage.trim().isEmpty) {
      throw ArgumentError.value(
        emptyMessage,
        'emptyMessage',
        'must not be empty',
      );
    }
    final ids = <String>{};
    for (final offer in offers) {
      if (offer.id.trim().isEmpty) {
        throw ArgumentError.value(offer.id, 'offer.id', 'must not be empty');
      }
      if (!ids.add(offer.id)) {
        throw ArgumentError.value(
          offer.id,
          'offers',
          'duplicate offer id: ${offer.id}',
        );
      }
      if (offer.title.trim().isEmpty) {
        throw ArgumentError.value(
          offer.title,
          'offer.title',
          'must not be empty',
        );
      }
      if (offer.priceLabel.trim().isEmpty) {
        throw ArgumentError.value(
          offer.priceLabel,
          'offer.priceLabel',
          'must not be empty',
        );
      }
    }
  }

  final List<DailyOffer> offers;
  final ValueChanged<String> onOpen;
  final String title;
  final String emptyMessage;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final semantics = semanticLabel ?? '$title. ${offers.length} offers.';
    return Semantics(
      key: const ValueKey('dailyOfferStackSemantics'),
      container: true,
      label: semantics,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          if (offers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.builder(
              key: const ValueKey('dailyOfferList'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offers.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _OfferRow(offer: offers[index], onOpen: onOpen),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.onOpen});

  final DailyOffer offer;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final expired = offer.isExpired;
    final accent = expired ? NeonTheme.muted : NeonTheme.gold;
    return Container(
      key: ValueKey('dailyOffer_${offer.id}'),
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(offer.icon, color: accent),
          ),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      offer.title,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (offer.badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          offer.badgeLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (offer.subtitle != null)
                  Text(
                    offer.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          CommonButton(
            key: ValueKey('dailyOfferOpen_${offer.id}'),
            label: expired ? 'Expired' : offer.priceLabel,
            width: 96,
            variant: expired
                ? CommonButtonVariant.secondary
                : CommonButtonVariant.primary,
            color: accent,
            onTap: expired ? null : () => onOpen(offer.id),
          ),
        ],
      ),
    );
  }
}
