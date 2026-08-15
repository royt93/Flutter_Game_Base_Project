import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/achievements.dart';
import '../../data/pigments.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';

class ColorAlchemyScreen extends StatelessWidget {
  const ColorAlchemyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'alchemy_title'.tr,
                color: NeonTheme.purple,
                actions: [CoinChip(controller)],
              ),
              Padding(
                padding: const EdgeInsets.all(NeonTheme.s16),
                child: Text(
                  'alchemy_hint'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonTheme.inkSoft),
                ),
              ),
              Expanded(
                child: Obx(() {
                  controller.coins.value;
                  controller.unlockedPigmentIds.length;
                  controller.unlockedAchievementIds.length;
                  controller.gemColorOverrides.length;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                    ),
                    // F19: bàn pha là mục ĐẦU TIÊN **trong** danh sách cuộn,
                    // không phải widget cố định phía trên. Đặt ngoài `ListView`
                    // thì màn hình tràn ngay trên máy nhỏ — 18 ca test cũ đỏ
                    // cùng lúc vì đúng chuyện đó.
                    itemCount: NeonTheme.gemColors.length + 1,
                    itemBuilder: (_, i) => i == 0
                        ? _FusionBench(controller: controller)
                        : _SlotRow(slot: i - 1, controller: controller),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.controller});
  final int slot;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final selectedId = controller.gemColorOverrides[slot];
    return Card(
      color: NeonTheme.card,
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      child: Padding(
        padding: const EdgeInsets.all(NeonTheme.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: resolvedGemColor(slot)),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    'alchemy_slot'.trParams({'slot': '${slot + 1}'}),
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selectedId != null)
                  TextButton(
                    onPressed: () => controller.clearGemColorOverride(slot),
                    child: Text('alchemy_reset'.tr),
                  ),
              ],
            ),
            Wrap(
              spacing: NeonTheme.s8,
              runSpacing: NeonTheme.s8,
              children: [
                for (final pigment in kPigments)
                  _PigmentChip(
                    pigment: pigment,
                    selected: pigment.id == selectedId,
                    controller: controller,
                    slot: slot,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PigmentChip extends StatelessWidget {
  const _PigmentChip({
    required this.pigment,
    required this.selected,
    required this.controller,
    required this.slot,
  });
  final Pigment pigment;
  final bool selected;
  final GameController controller;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.isPigmentUnlocked(pigment);
    return PressableScale(
      onTap: () {
        if (unlocked) {
          controller.setGemColorOverride(slot, pigment.id);
        } else if (pigment.coinPrice != null &&
            controller.buyPigment(pigment)) {
          controller.setGemColorOverride(slot, pigment.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: pigment.color.withValues(alpha: unlocked ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? pigment.color : NeonTheme.inkSoft,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 7, backgroundColor: pigment.color),
            const SizedBox(width: 5),
            // `Flexible` chứ không `Text` trần: `Wrap` xuống dòng giữa các
            // chip nhưng không thu nhỏ một chip rộng hơn cả dòng. Tên pigment
            // tiếng Đức/Filipino dài hơn tiếng Anh đủ để tràn — cắt bớt còn
            // hơn vẽ đè ra ngoài viền.
            Flexible(
              child: Text(pigment.nameKey.tr, overflow: TextOverflow.ellipsis),
            ),
            if (!unlocked) ...[
              const SizedBox(width: 4),
              Text(
                // F19: dạng mở khoá thứ tư (fusion) không có coin lẫn
                // achievement. Bản cũ giả định luôn có một trong hai và gọi
                // `firstWhere` không `orElse` — thêm pigment fusion là màn hình
                // ném `Bad state: No element` ngay khi dựng.
                _lockLabel(pigment),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// F19: bàn pha chế — chọn 2 pigment đã sở hữu, tiêu craft point, ra pigment
/// hiếm.
class _FusionBench extends StatefulWidget {
  const _FusionBench({required this.controller});

  final GameController controller;

  @override
  State<_FusionBench> createState() => _FusionBenchState();
}

class _FusionBenchState extends State<_FusionBench> {
  String? _a;
  String? _b;
  String? _message;

  void _pick(String id) {
    setState(() {
      _message = null;
      if (_a == id) {
        _a = null;
      } else if (_b == id) {
        _b = null;
      } else if (_a == null) {
        _a = id;
      } else if (_b == null) {
        _b = id;
      } else {
        _a = _b;
        _b = id;
      }
    });
  }

  void _fuse() {
    final a = _a, b = _b;
    if (a == null || b == null) {
      setState(() => _message = 'fusion_pick'.tr);
      return;
    }
    final result = widget.controller.fusePigments(a, b);
    setState(() {
      if (result != null) {
        _message = 'fusion_done'.trParams({
          'name': kPigments.firstWhere((p) => p.id == result).nameKey.tr,
        });
        _a = null;
        _b = null;
        return;
      }
      // Phân biệt hai lý do thất bại: không có công thức vs thiếu điểm. Gộp
      // thành một câu chung thì người chơi không biết nên đổi màu hay đi kiếm
      // thêm điểm.
      _message = fusionResultFor(a, b) == null
          ? 'fusion_no_recipe'.tr
          : 'fusion_need_cp'.tr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final owned = kPigments
          .where(widget.controller.isPigmentUnlocked)
          .toList();
      return Container(
        key: const Key('fusion_bench'),
        margin: const EdgeInsets.only(bottom: NeonTheme.s8),
        padding: const EdgeInsets.all(NeonTheme.s8),
        decoration: BoxDecoration(
          color: NeonTheme.cardAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'fusion_title'.tr,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // `Flexible`: chuỗi này dài theo bản dịch và theo cỡ chữ hệ
                // thống, hàng chỉ rộng bằng thẻ chứa nó.
                Flexible(
                  child: Text(
                    'fusion_cp'.trParams({
                      'n': '${widget.controller.craftPoints.value}',
                    }),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'fusion_hint'.tr,
              style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
            ),
            const SizedBox(height: NeonTheme.s8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in owned)
                  PressableScale(
                    key: Key('fusion_pick_${p.id}'),
                    onTap: () => _pick(p.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (p.id == _a || p.id == _b)
                              ? p.color
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Text(
                        p.nameKey.tr,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            Row(
              children: [
                PressableScale(
                  key: const Key('fusion_fuse'),
                  onTap: _fuse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                      vertical: NeonTheme.s8,
                    ),
                    decoration: BoxDecoration(
                      color: NeonTheme.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'fusion_cost'.trParams({'n': '$kFusionCraftCost'}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    _message ??
                        'fusion_book'.trParams({
                          'n': '${widget.controller.discoveredRecipes.length}',
                          'total': '${kPigmentRecipes.length}',
                        }),
                    style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Nhãn giải thích vì sao pigment còn khoá.
String _lockLabel(Pigment pigment) {
  if (pigment.fusionOnly) return 'pigment_fusion_only'.tr;
  final price = pigment.coinPrice;
  if (price != null) return fmtNum(price);
  final match = kAchievements.where((a) => a.id == pigment.unlockAchievementId);
  return match.isEmpty ? '' : match.first.titleKey.tr;
}
