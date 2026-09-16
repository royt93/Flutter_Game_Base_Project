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
    this.buttonColor,
    this.buttonVariant = CommonButtonVariant.primary,
    this.loading = false,
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

  /// Buy button color — e.g. a "best value" item wanting a more prominent
  /// color than the default. Passed straight through to [CommonButton].
  final Color? buttonColor;

  /// Buy button variant — defaults to [CommonButtonVariant.primary],
  /// matching the prior hardcoded behavior.
  final CommonButtonVariant buttonVariant;

  /// IDEA-53/ENH-66: forwarded straight to the "Buy" [CommonButton] —
  /// shows a spinner and blocks double-tap while an in-flight purchase
  /// (a real IAP call to the store, which can take a few seconds) is
  /// pending. `false` (default) keeps the exact prior behavior.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: width,
      child: PanelCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(NeonTheme.s8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: NeonTheme.glow(
                  iconColor ?? NeonTheme.purple,
                  blur: 10,
                  intensity: 0.4,
                ),
              ),
              child: Icon(icon, size: 40, color: iconColor ?? NeonTheme.purple),
            ),
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
              variant: buttonVariant,
              color: buttonColor,
              loading: loading,
            ),
          ],
        ),
      ),
    );
    final withRibbon = ribbonText == null
        ? card
        : RibbonBadge(text: ribbonText!, color: ribbonColor, child: card);
    // ENH-44: merges every descendant semantics node (title text, buy
    // button, ribbon text if any) into ONE node instead of 3+ separate
    // ones a screen reader would announce individually — a shop grid item
    // is conceptually a single unit. MergeSemantics (unlike a plain
    // Semantics(label: ...)) also preserves the button role/tap action
    // from CommonButton on the merged node, so it stays activatable.
    return MergeSemantics(child: withRibbon);
  }
}
