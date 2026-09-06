import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'panel_card.dart';
import 'ribbon_badge.dart';

/// Ready-made shop/IAP grid item: icon + title + price pill, composed from
/// [PanelCard] + [CommonButton] (and optionally [RibbonBadge]) rather than
/// every app re-assembling those by hand. Pure presentation — [priceLabel]
/// is a caller-formatted string (e.g. `"$0.99"`), and [onBuy] is just a
/// callback; this widget never calls into `in_app_purchase` itself (that's
/// FEAT-01's job).
class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.icon,
    required this.title,
    required this.priceLabel,
    required this.onBuy,
    this.ribbonText,
    this.ribbonColor,
    this.iconColor,
    this.width = 160,
  });

  final IconData icon;
  final String title;

  /// Caller-formatted price, e.g. `"$0.99"` — this widget does no currency
  /// formatting itself.
  final String priceLabel;

  final VoidCallback? onBuy;

  /// Corner ribbon label (e.g. "SALE", "NEW") — omit for a plain card.
  final String? ribbonText;

  /// Ribbon color, only used when [ribbonText] is set. Default:
  /// [RibbonBadge]'s own default ([NeonTheme.red]).
  final Color? ribbonColor;

  final Color? iconColor;

  /// Card width — also sizes the buy button to fit inside it.
  final double width;

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: width,
      child: PanelCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor ?? NeonTheme.purple),
            const SizedBox(height: NeonTheme.s8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: NeonTheme.s16),
            CommonButton(
              label: priceLabel,
              onTap: onBuy,
              width: width - NeonTheme.s16 * 2,
            ),
          ],
        ),
      ),
    );
    if (ribbonText == null) return card;
    return RibbonBadge(text: ribbonText!, color: ribbonColor, child: card);
  }
}
