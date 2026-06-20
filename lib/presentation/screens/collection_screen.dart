import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/collection.dart';
import '../controllers/collection_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Album sưu tập — lưới sticker mở khoá theo điểm tích luỹ (Wave 14).
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    // Dùng find trước (controller đã permanent từ Home); fallback put nếu test mount
    // screen độc lập (không qua HomeScreen) → tránh ném exception.
    final cc = Get.isRegistered<CollectionController>()
        ? Get.find<CollectionController>()
        : Get.put(CollectionController(g));
    const accent = NeonTheme.cyan;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'coll_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  cc.points.value;
                  cc.claimed.length;
                  cc.setRewardClaimed.value;
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _banner(cc, accent),
                      const SizedBox(height: NeonTheme.s16),
                      _setReward(cc),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kCollectionItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: NeonTheme.s8,
                          crossAxisSpacing: NeonTheme.s8,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (_, i) => _cell(cc, i),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(CollectionController cc, Color accent) => Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent, width: 1.5),
          boxShadow: NeonTheme.glow(accent, blur: 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_album_rounded, color: accent, size: 24),
                const SizedBox(width: 8),
                Text(
                  '${cc.unlockedCount}/${cc.totalCount}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: accent, blurRadius: 12)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
                const SizedBox(width: 5),
                Text(
                  '${cc.points.value} ${'coll_points'.tr}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'coll_hint'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  /// W18.2: thẻ thưởng HOÀN TẤT BỘ (skin gem độc quyền + xu) — chỉ hiện khi đủ.
  Widget _setReward(CollectionController cc) {
    if (!cc.allCollected) return const SizedBox.shrink();
    final done = cc.setRewardClaimed.value;
    const gold = NeonTheme.yellow;
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s16),
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold, width: 1.6),
        boxShadow: NeonTheme.glow(gold, blur: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: gold, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('coll_set_title'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )),
                // H1 fix: hiện đúng mô tả theo trường hợp — skin mới vs đã sở hữu.
                Builder(builder: (context) {
                  final g = Get.find<GameController>();
                  final alreadyOwned = g.isSkinOwned(kCollectionSetSkin);
                  final desc = alreadyOwned
                      ? 'coll_set_owned_reward'.trParams(
                          {'n': fmtNum(kCollectionSetSkinPrice)})
                      : 'coll_set_reward'.trParams(
                          {'n': fmtNum(kCollectionSetCoins)});
                  return Text(
                    desc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Colors.grey, size: 26)
          else
            GestureDetector(
              onTap: cc.claimSetReward,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: NeonTheme.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeonTheme.lime, width: 1.5),
                  boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
                ),
                child: Text('daily_claim'.tr,
                    style: const TextStyle(
                      color: NeonTheme.lime,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(CollectionController cc, int i) {
    final it = kCollectionItems[i];
    final color = NeonTheme.gemColors[it.colorIndex % NeonTheme.gemColors.length];
    final claimed = cc.isClaimed(i);
    final canClaim = cc.canClaim(i);
    return GestureDetector(
      onTap: canClaim ? () => cc.claim(i) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: claimed ? 0.7 : 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: claimed ? color : (canClaim ? NeonTheme.lime : Colors.white24),
            width: claimed || canClaim ? 1.8 : 1.2,
          ),
          boxShadow: canClaim
              ? NeonTheme.glow(NeonTheme.lime, blur: 8)
              : (claimed ? NeonTheme.glow(color, blur: 6) : null),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hình sticker: lộ màu khi đã mở, bóng mờ "?" khi chưa.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: claimed
                    ? color.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                boxShadow: claimed ? NeonTheme.glow(color, blur: 10) : null,
              ),
              child: claimed
                  ? const Icon(Icons.star_rounded, color: Colors.white, size: 22)
                  : Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              claimed ? it.nameKey.tr : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: claimed ? Colors.white : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            // W18.2: vật sưu tập — "thu thập" (canClaim) / "đã có" (claimed) /
            // ngưỡng điểm (chưa tới). KHÔNG còn thưởng xu riêng từng ô.
            if (canClaim)
              const Icon(Icons.add_circle_rounded,
                  color: NeonTheme.lime, size: 14)
            else if (claimed)
              Icon(Icons.check_rounded, color: color, size: 13)
            else
              Text(
                '${it.threshold}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
