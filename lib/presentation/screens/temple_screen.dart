import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/temple.dart';
import '../controllers/game_controller.dart';
import '../controllers/temple_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';

/// Màn "Đền Neon" — tiêu Shard xây/nâng cấp các hạng mục công trình.
/// Meta-progression ngoài lưới (Wave 7): chơi level → có shard → xây đền.
class TempleScreen extends StatelessWidget {
  const TempleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final t = Get.put(TempleController(g));
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'temple_title'.tr,
                color: NeonTheme.cyan,
                actions: [_shardChip(g), _coinChip(g)],
              ),
              _progressBar(t),
              Expanded(child: _templeView(t)),
              _panel(g, t),
            ],
          ),
        ),
      ),
    );
  }

  // --- Thanh tiến trình tổng thể đền ---
  Widget _progressBar(TempleController t) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s16, vertical: NeonTheme.s8),
      child: Obx(() {
        t.builtTier.length; // chạm để rebuild
        final p = t.progress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'temple_progress'.tr}: ${t.builtCount}/${t.totalCount}',
              style: const TextStyle(
                fontFamily: 'Baloo2',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 8,
                backgroundColor: NeonTheme.panel.withValues(alpha: 0.6),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(NeonTheme.cyan),
              ),
            ),
          ],
        );
      }),
    );
  }

  // --- Khung đền: nền vẽ + các node bấm được ---
  Widget _templeView(TempleController t) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return Obx(() {
        t.builtTier.length;
        t.selectedId.value;
        return Stack(
          children: [
            // Nền: các tia nối node + ánh sáng tổng
            Positioned.fill(
              child: CustomPaint(
                painter: _TemplePainter(t),
              ),
            ),
            // Node bấm được
            for (final n in kTempleNodes)
              Positioned(
                left: n.pos.dx * size.width - 30,
                top: n.pos.dy * size.height - 30,
                child: GestureDetector(
                  onTap: () => t.select(n.id),
                  child: _NodeBadge(
                    node: n,
                    tier: t.tierOf(n),
                    selected: t.selectedId.value == n.id,
                  ),
                ),
              ),
          ],
        );
      });
    });
  }

  // --- Panel dưới: hạng mục đang chọn + nút xây ---
  Widget _panel(GameController g, TempleController t) {
    return Obx(() {
      g.shards.value;
      t.builtTier.length;
      final id = t.selectedId.value;
      if (id.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(NeonTheme.s16),
          child: Text(
            'temple_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      final n = kTempleNodes.firstWhere((e) => e.id == id);
      final tier = t.tierOf(n);
      final next = t.nextTier(n);
      final maxed = next == null;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(NeonTheme.s16),
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.accent, width: 1.5),
          boxShadow: NeonTheme.glow(n.accent, blur: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  n.nameKey.tr,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: n.accent, blurRadius: 12)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${'temple_tier'.tr} $tier/${n.maxTier}',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    color: n.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              n.descKey.tr,
              style: TextStyle(
                fontFamily: 'Baloo2',
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (maxed)
              Center(
                child: Text(
                  'temple_maxed'.tr,
                  style: const TextStyle(
                    fontFamily: 'Baloo2',
                    color: NeonTheme.lime,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Icon(Icons.diamond_rounded, color: n.accent, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    '${next.cost}',
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '· +${next.rewardCoins} ${'coins_short'.tr}',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  NeonButton(
                    label: 'temple_build'.tr,
                    color: t.canBuild(n) ? n.accent : Colors.grey,
                    icon: Icons.construction_rounded,
                    onTap: () {
                      if (t.build(n)) {
                        Get.snackbar(
                          'temple_built'.tr,
                          '${n.nameKey.tr} · ${'temple_tier'.tr} ${t.tierOf(n)}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: NeonTheme.panel,
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(NeonTheme.s16),
                          duration: const Duration(seconds: 2),
                        );
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _shardChip(GameController g) => _chip(
        Icons.diamond_rounded,
        NeonTheme.cyan,
        () => g.shards.value,
        g,
      );

  Widget _coinChip(GameController g) => _chip(
        Icons.monetization_on_rounded,
        NeonTheme.yellow,
        () => g.coins.value,
        g,
      );

  Widget _chip(IconData icon, Color color, int Function() value, GameController g) {
    return Container(
      margin: const EdgeInsets.only(right: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: NeonTheme.glow(color, blur: 6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Obx(() => Text('${value()}',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ))),
      ]),
    );
  }
}

/// Huy hiệu 1 hạng mục: vòng tròn sáng dần theo tier + chấm tier.
class _NodeBadge extends StatelessWidget {
  final TempleNode node;
  final int tier;
  final bool selected;
  const _NodeBadge(
      {required this.node, required this.tier, required this.selected});

  @override
  Widget build(BuildContext context) {
    final built = tier > 0;
    final intensity = node.maxTier == 0 ? 0.0 : tier / node.maxTier;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NeonTheme.panel.withValues(alpha: built ? 0.85 : 0.4),
        border: Border.all(
          color: built
              ? node.accent
              : node.accent.withValues(alpha: 0.4),
          width: selected ? 3 : 2,
        ),
        boxShadow: NeonTheme.glow(
          node.accent,
          blur: 6 + 14 * intensity + (selected ? 6 : 0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            built ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
            color: built ? node.accent : Colors.white.withValues(alpha: 0.6),
            size: 22,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < node.maxTier; i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < tier
                        ? node.accent
                        : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vẽ tia nối các node theo thứ tự (Cổng → Đền → Lõi) cho cảm giác liền mạch.
class _TemplePainter extends CustomPainter {
  final TempleController t;
  _TemplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(TempleNode n) =>
        Offset(n.pos.dx * size.width, n.pos.dy * size.height);
    // Thứ tự nối tạo dáng đền: gate → altar → spire → core; 2 trụ nối altar.
    final byId = {for (final n in kTempleNodes) n.id: n};
    void line(String a, String b) {
      final na = byId[a], nb = byId[b];
      if (na == null || nb == null) return;
      final built = (t.tierOf(na) > 0) && (t.tierOf(nb) > 0);
      final paint = Paint()
        ..color = NeonTheme.cyan.withValues(alpha: built ? 0.5 : 0.15)
        ..strokeWidth = built ? 2.5 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p(na), p(nb), paint);
    }

    line('gate', 'altar');
    line('pillarL', 'altar');
    line('pillarR', 'altar');
    line('altar', 'spire');
    line('spire', 'core');
  }

  @override
  bool shouldRepaint(covariant _TemplePainter old) => true;
}
