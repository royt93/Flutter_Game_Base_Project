import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/star_pets.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/star_pet_habitat.dart';

/// I65: chuồng thú cưng sao — sưu tầm nhiều pet cùng lúc bằng Star Dust, thu
/// hoạch xu idle tích luỹ theo thời gian rời app. Không bao giờ hiển thị
/// trong `game_screen.dart` (chỉ ở đây/home).
class PetHabitatScreen extends StatelessWidget {
  const PetHabitatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'pet_habitat_title'.tr,
                color: NeonTheme.teal,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(() {
                  gameCtrl.starOwnedPets.length;
                  gameCtrl.starDust.value;
                  gameCtrl.lastPetCollectMs.value;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _starDustBar(gameCtrl),
                        const SizedBox(height: NeonTheme.s16),
                        Container(
                          padding: const EdgeInsets.all(NeonTheme.s16),
                          decoration: BoxDecoration(
                            color: NeonTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: NeonTheme.drop(),
                          ),
                          constraints: const BoxConstraints(minHeight: 96),
                          child: gameCtrl.starOwnedPets.isEmpty
                              ? Center(
                                  child: Text(
                                    'pet_habitat_empty'.tr,
                                    style: TextStyle(
                                      color: NeonTheme.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : StarPetHabitat(pets: gameCtrl.starOwnedPets),
                        ),
                        const SizedBox(height: NeonTheme.s24),
                        Text(
                          'pet_habitat_hatch_section'.tr,
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: NeonTheme.s16,
                                crossAxisSpacing: NeonTheme.s16,
                                childAspectRatio: 0.9,
                              ),
                          itemCount: kStarPetTypes.length,
                          itemBuilder: (context, i) {
                            final type = kStarPetTypes[i];
                            final owned = gameCtrl.starOwnedPets
                                .where((p) => p.typeId == type.id)
                                .length;
                            final canAfford =
                                gameCtrl.starDust.value >= type.hatchCost;
                            return _HatchCard(
                              type: type,
                              owned: owned,
                              canAfford: canAfford,
                              onHatch: () => gameCtrl.hatchPet(type),
                              // I82: chỉ trang bị được con đã sở hữu; bấm lại
                              // con đang trang bị để tháo.
                              equipped:
                                  gameCtrl.equippedPetTypeId.value == type.id,
                              onEquip: owned > 0
                                  ? () => gameCtrl.equipPet(
                                      gameCtrl.equippedPetTypeId.value ==
                                              type.id
                                          ? ''
                                          : type.id,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starDustBar(GameController gameCtrl) {
    final pending = gameCtrl.pendingIdlePetReward;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeonTheme.drop(),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: NeonTheme.teal,
            size: 22,
          ),
          const SizedBox(width: NeonTheme.s8),
          Text(
            fmtNum(gameCtrl.starDust.value),
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'pet_habitat_star_dust_label'.tr,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (pending > 0)
            PressableScale(
              onTap: gameCtrl.claimIdlePetReward,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NeonTheme.yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'pet_habitat_claim_button'.trParams({
                        'amount': fmtNum(pending),
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HatchCard extends StatelessWidget {
  const _HatchCard({
    required this.type,
    required this.owned,
    required this.canAfford,
    required this.onHatch,
    required this.equipped,
    this.onEquip,
  });

  final PetType type;
  final int owned;
  final bool canAfford;
  final VoidCallback onHatch;

  /// I82: pet này đang được trang bị chưa.
  final bool equipped;

  /// Null nếu chưa sở hữu con nào — nút trang bị bị vô hiệu.
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonTheme.teal.withValues(alpha: 0.4)),
        boxShadow: NeonTheme.drop(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Center(
              child: StarPetHabitat(
                pets: [PetInstance(typeId: type.id, hatchedAtMs: 0)],
                petSize: 56,
              ),
            ),
          ),
          Text(
            type.nameKey.tr,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (owned > 0)
            Text(
              'pet_habitat_owned_count'.trParams({'count': '$owned'}),
              style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
            ),
          // I82: nhãn passive — hiệu ứng vô hình là hiệu ứng không tồn tại.
          Text(
            _passiveLabel(type.passive),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonTheme.teal,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onEquip != null) ...[
            const SizedBox(height: 4),
            PressableScale(
              onTap: onEquip,
              child: Container(
                key: Key('equip_${type.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: equipped ? NeonTheme.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NeonTheme.teal, width: 2),
                ),
                child: Text(
                  equipped ? 'pet_equipped'.tr : 'pet_equip'.tr,
                  style: TextStyle(
                    color: equipped ? Colors.white : NeonTheme.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: NeonTheme.s8),
          PressableScale(
            onTap: canAfford ? onHatch : null,
            child: Container(
              key: Key('hatch_${type.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canAfford ? NeonTheme.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canAfford ? NeonTheme.teal : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: canAfford ? Colors.white : NeonTheme.inkSoft,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'pet_habitat_hatch_button'.trParams({
                      'cost': '${type.hatchCost}',
                    }),
                    style: TextStyle(
                      color: canAfford ? Colors.white : NeonTheme.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// I82: nhãn mô tả passive của một loại pet.
String _passiveLabel(PetPassive passive) => switch (passive) {
  PetPassive.extraUndo => 'pet_passive_undo'.tr,
  PetPassive.extraHint => 'pet_passive_hint'.tr,
  PetPassive.coinBonus => 'pet_passive_coin'.tr,
};
