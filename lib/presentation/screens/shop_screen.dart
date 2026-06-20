import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/cosmetics.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';

/// Thông báo mua hàng dùng dialog neon chung (NeonDialog) — ShopScreen là route
/// Flutter thuần (không có Flame GameWidget) nên route dialog hiển thị bình thường.
void _shopDialog(
  BuildContext context, {
  required String title,
  required Color color,
  required IconData icon,
  String? message,
}) {
  NeonDialog.show(
    context: context,
    title: title,
    color: color,
    icon: icon,
    message: message,
    dismissible: true,
    actions: [
      NeonDialogAction(label: 'confirm'.tr, color: color, onTap: () {}),
    ],
  );
}

/// Cửa hàng trang trí (Wave 9): mua skin gem + theme bàn bằng xu.
/// Mua xong tự trang bị; chọn lại item đã sở hữu để đổi. Không ảnh hưởng gameplay.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'shop_title'.tr,
                color: NeonTheme.magenta,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      NeonTheme.s16, 0, NeonTheme.s16, NeonTheme.s24),
                  children: [
                    // W18.3 — coin-sink: nâng cấp booster vĩnh viễn.
                    _sectionHeader('shop_upgrades'.tr, NeonTheme.orange),
                    _UpgradeCard(
                      g: g,
                      icon: Icons.gavel_rounded,
                      name: 'upg_hammer'.tr,
                      desc: 'upg_hammer_desc'.tr,
                      price: kUpgradeHammerPrice,
                      upgraded: g.hammerUpgraded,
                      onBuy: g.buyUpgradeHammer,
                    ),
                    const SizedBox(height: NeonTheme.s8),
                    _UpgradeCard(
                      g: g,
                      icon: Icons.add_circle_rounded,
                      name: 'upg_moves'.tr,
                      desc: 'upg_moves_desc'.tr,
                      price: kUpgradeMovesPrice,
                      upgraded: g.movesUpgraded,
                      onBuy: g.buyUpgradeMoves,
                    ),
                    const SizedBox(height: NeonTheme.s24),
                    _sectionHeader('shop_skins'.tr, NeonTheme.cyan),
                    _grid([
                      for (final s in kGemSkins)
                        _SkinCard(g: g, skin: s),
                    ]),
                    const SizedBox(height: NeonTheme.s24),
                    _sectionHeader('shop_themes'.tr, NeonTheme.lime),
                    _grid([
                      for (final t in kBoardThemes)
                        _ThemeCard(g: g, theme: t),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Baloo2',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            shadows: [Shadow(color: color, blurRadius: 12)],
          ),
        ),
      );

  Widget _grid(List<Widget> cards) => Wrap(
        spacing: NeonTheme.s16,
        runSpacing: NeonTheme.s16,
        children: cards,
      );
}

/// W18.3 — thẻ nâng cấp booster vĩnh viễn (coin-sink). Mua 1 lần → "Đã có".
/// Nhận [upgraded] là RxBool trực tiếp → Obx tự track, không cần callback wrapper.
class _UpgradeCard extends StatelessWidget {
  final GameController g;
  final IconData icon;
  final String name;
  final String desc;
  final int price;
  final RxBool upgraded;
  final bool Function() onBuy;

  const _UpgradeCard({
    required this.g,
    required this.icon,
    required this.name,
    required this.desc,
    required this.price,
    required this.upgraded,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      g.coins.value; // rebuild khi xu đổi (để nút mua disable/enable đúng)
      final isOwned = upgraded.value; // RxBool → dependency tự đăng ký
      const accent = NeonTheme.orange;
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwned ? accent : accent.withValues(alpha: 0.4),
            width: isOwned ? 2 : 1.2,
          ),
          boxShadow: isOwned ? NeonTheme.glow(accent, blur: 8) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 30),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(desc,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            if (isOwned)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, color: NeonTheme.lime, size: 18),
                const SizedBox(width: 4),
                Text('shop_owned'.tr,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      color: NeonTheme.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    )),
              ])
            else
              Builder(builder: (_) {
                // H3 fix: visual disabled state khi không đủ xu.
                final canAfford = g.coins.value >= price;
                return GestureDetector(
                  onTap: canAfford
                      ? () {
                          if (onBuy()) {
                            _shopDialog(context,
                                title: name,
                                color: NeonTheme.lime,
                                icon: Icons.check_circle_rounded,
                                message: desc);
                          }
                        }
                      : () => _shopDialog(context,
                          title: 'not_enough_coins'.tr,
                          color: NeonTheme.yellow,
                          icon: Icons.account_balance_wallet_rounded),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NeonTheme.panel.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canAfford ? NeonTheme.yellow : Colors.white24,
                        width: 1.5),
                    ),
                    child: Text('💰 ${fmtNum(price)}',
                        style: TextStyle(
                          fontFamily: 'Baloo2',
                          color: canAfford ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                );
              }),  // Builder
          ],
        ),
      );
    });  // Obx
  }
}

/// Khung thẻ chung: preview + tên + nút hành động (mua / dùng / đang dùng).
class _CosmeticCard extends StatelessWidget {
  final Widget preview;
  final String name;
  final int price;
  final bool owned;
  final bool equipped;
  final Color accent;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _CosmeticCard({
    required this.preview,
    required this.name,
    required this.price,
    required this.owned,
    required this.equipped,
    required this.accent,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - NeonTheme.s16 * 3) / 2;
    return SizedBox(
      width: w.clamp(120.0, 240.0),
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s8),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: equipped ? accent : accent.withValues(alpha: 0.35),
            width: equipped ? 2.5 : 1.2,
          ),
          boxShadow: equipped ? NeonTheme.glow(accent, blur: 10) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1.6, child: preview),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Baloo2',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    if (equipped) {
      return _pill('shop_equipped'.tr, accent, filled: true, onTap: null);
    }
    if (owned) {
      return _pill('shop_equip'.tr, accent, filled: false, onTap: onEquip);
    }
    return _pill('💰 ${fmtNum(price)}', NeonTheme.yellow, filled: false, onTap: onBuy);
  }

  Widget _pill(String label, Color color,
      {required bool filled, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.22)
              : NeonTheme.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final GameController g;
  final GemSkin skin;
  const _SkinCard({required this.g, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final owned = g.isSkinOwned(skin.id);
      final equipped = g.selectedSkin.value == skin.id;
      return _CosmeticCard(
        preview: CustomPaint(painter: _SkinPreviewPainter(skin)),
        name: skin.name,
        price: skin.price,
        owned: owned,
        equipped: equipped,
        accent: skin.colors.first,
        onBuy: () => _buy(context),
        onEquip: () => g.selectSkin(skin.id),
      );
    });
  }

  void _buy(BuildContext context) {
    if (g.buySkin(skin.id)) {
      _shopDialog(context,
          title: skin.name,
          color: NeonTheme.lime,
          icon: Icons.check_circle_rounded,
          message: 'shop_equipped'.tr);
    } else {
      _shopDialog(context,
          title: 'not_enough_coins'.tr,
          color: NeonTheme.yellow,
          icon: Icons.account_balance_wallet_rounded);
    }
  }
}

class _ThemeCard extends StatelessWidget {
  final GameController g;
  final BoardTheme theme;
  const _ThemeCard({required this.g, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final owned = g.isThemeOwned(theme.id);
      final equipped = g.selectedTheme.value == theme.id;
      return _CosmeticCard(
        preview: CustomPaint(painter: _ThemePreviewPainter(theme)),
        name: theme.name,
        price: theme.price,
        owned: owned,
        equipped: equipped,
        accent: theme.accent,
        onBuy: () => _buy(context),
        onEquip: () => g.selectTheme(theme.id),
      );
    });
  }

  void _buy(BuildContext context) {
    if (g.buyTheme(theme.id)) {
      _shopDialog(context,
          title: theme.name,
          color: NeonTheme.lime,
          icon: Icons.check_circle_rounded,
          message: 'shop_equipped'.tr);
    } else {
      _shopDialog(context,
          title: 'not_enough_coins'.tr,
          color: NeonTheme.yellow,
          icon: Icons.account_balance_wallet_rounded);
    }
  }
}

/// Preview skin: 6 gem nhỏ (palette + hình theo họ) phát sáng.
class _SkinPreviewPainter extends CustomPainter {
  final GemSkin skin;
  _SkinPreviewPainter(this.skin);

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 3, rows = 2;
    final cw = size.width / cols, ch = size.height / rows;
    final r = math.min(cw, ch) * 0.32;
    for (int i = 0; i < 6; i++) {
      final cx = (i % cols + 0.5) * cw;
      final cy = (i ~/ cols + 0.5) * ch;
      final center = Offset(cx, cy);
      final color = skin.colors[i];
      canvas.drawCircle(
        center,
        r * 1.7,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        _miniShape(skin.shapeFamily, center, r),
        Paint()..color = color,
      );
    }
  }

  Path _miniShape(int family, Offset c, double r) {
    switch (family) {
      case 1: // hình học → lục giác
        return _poly(c, r * 1.15, 6, -math.pi / 2);
      case 2: // tinh thể → thoi
        return _poly(c, r * 1.2, 4, 0);
      default: // lá bài → tròn
        return Path()..addOval(Rect.fromCircle(center: c, radius: r));
    }
  }

  Path _poly(Offset c, double radius, int sides, double rot) {
    final p = Path();
    for (int i = 0; i < sides; i++) {
      final a = rot + i * 2 * math.pi / sides;
      final pt = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant _SkinPreviewPainter old) => old.skin.id != skin.id;
}

/// Preview theme bàn: khung bo góc + viền neon đôi + tông ô.
class _ThemePreviewPainter extends CustomPainter {
  final BoardTheme theme;
  _ThemePreviewPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final panel = RRect.fromRectAndRadius(
        rect.deflate(6), const Radius.circular(12));
    canvas.drawRRect(panel, Paint()..color = const Color(0xE60B0B1F));
    if (theme.slotTint.a > 0) {
      canvas.drawRRect(panel, Paint()..color = theme.slotTint);
    }
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = theme.border1.withValues(alpha: 0.7),
    );
    canvas.drawRRect(
      panel.inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = theme.border2.withValues(alpha: 0.5),
    );
    // vài chấm accent gợi gem trên bàn
    final dot = Paint()..color = theme.accent.withValues(alpha: 0.85);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.3 + i * 0.2), size.height * 0.5),
        size.height * 0.08,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThemePreviewPainter old) =>
      old.theme.id != theme.id;
}
