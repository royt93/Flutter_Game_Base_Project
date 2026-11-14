import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/app_version_gate.dart';
import 'package:roy_casual_kit/core/inventory_service.dart' show ItemRarity;
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// True when a [Semantics] widget with exactly this label exists in the tree.
/// Checked on the widget tree, not on the merged semantics nodes: a parent
/// with its own label can absorb a child's label there.
Finder semanticsLabeled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

/// FEAT-203 phase 2: every user-visible default that used to be hard-coded can
/// now be replaced by the consumer (same pattern as ENH-105).
void main() {
  testWidgets('EnergyBar.refillLabel', (tester) async {
    await tester.pumpWidget(
      host(
        EnergyBar(
          currentEnergy: 2,
          maxEnergy: 5,
          timeUntilNextEnergy: const Duration(minutes: 3),
          onRefillTap: () {},
          refillLabel: 'Nạp thêm tim',
        ),
      ),
    );
    expect(semanticsLabeled('Nạp thêm tim'), findsOneWidget);
    expect(semanticsLabeled('Refill lives'), findsNothing);
  });

  testWidgets('CandySearchBar.clearLabel', (tester) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        CandySearchBar(
          controller: controller,
          onChanged: (_) {},
          clearLabel: 'Xoá tìm kiếm',
        ),
      ),
    );
    await tester.pump();
    expect(semanticsLabeled('Xoá tìm kiếm'), findsOneWidget);
  });

  testWidgets('RewardChoicePanel.emptyMessage and claimedLabel', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RewardChoicePanel(
          options: const [],
          onConfirm: (_) async {},
          emptyMessage: 'Không có phần thưởng.',
        ),
      ),
    );
    expect(find.text('Không có phần thưởng.'), findsOneWidget);
    expect(find.text('No rewards to choose from.'), findsNothing);

    await tester.pumpWidget(
      host(
        RewardChoicePanel(
          options: const [RewardChoiceOption(id: 'a', label: 'Gems')],
          claimedIds: const {'a'},
          onConfirm: (_) async {},
          claimedLabel: 'Đã nhận',
        ),
      ),
    );
    expect(find.text('Đã nhận'), findsOneWidget);
    expect(find.text('Claimed'), findsNothing);
  });

  testWidgets('PrestigeConfirmationCard multiplier and rewards labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PrestigeConfirmationCard(
          currentLevel: 50,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1,
          nextMultiplier: 1.5,
          rewards: const [
            PrestigeReward(icon: Icons.bolt, label: 'Speed', amount: '+25%'),
          ],
          onConfirm: () {},
          onCancel: () {},
          currentLabel: 'Hiện tại',
          afterPrestigeLabel: 'Sau khi thăng cấp',
          rewardsHeader: 'Phần thưởng vĩnh viễn',
        ),
      ),
    );
    expect(find.text('Hiện tại'), findsOneWidget);
    expect(find.text('Sau khi thăng cấp'), findsOneWidget);
    expect(find.text('Phần thưởng vĩnh viễn'), findsOneWidget);
    expect(find.text('Permanent Rewards'), findsNothing);
  });

  testWidgets('StreakShieldCard metric labels', (tester) async {
    await tester.pumpWidget(
      host(
        StreakShieldCard(
          streakDays: 7,
          shieldCount: 1,
          currentStreakLabel: 'Chuỗi hiện tại',
          shieldsLabel: 'Khiên bảo vệ',
        ),
      ),
    );
    expect(find.text('Chuỗi hiện tại'), findsOneWidget);
    expect(find.text('Khiên bảo vệ'), findsOneWidget);
    expect(find.text('Freeze Shields'), findsNothing);
  });

  testWidgets('CommunityLeaderboardCard.refreshLabel', (tester) async {
    await tester.pumpWidget(
      host(
        CommunityLeaderboardCard(
          entries: const [],
          onRefresh: () {},
          refreshLabel: 'Làm mới',
        ),
      ),
    );
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('communityLeaderboardRefresh')),
    );
    expect(button.tooltip, 'Làm mới');
    expect(
      () => CommunityLeaderboardCard(entries: const [], refreshLabel: ' '),
      throwsArgumentError,
    );
  });

  testWidgets('SaveSlotPicker labels and delete message builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SaveSlotPicker(
          slots: const [
            SaveSlotMeta(
              id: 's1',
              displayName: 'Alice',
              createdAtMs: 1,
              lastPlayedAtMs: 1,
            ),
            SaveSlotMeta(
              id: 's2',
              displayName: 'Bob',
              createdAtMs: 2,
              lastPlayedAtMs: 2,
            ),
          ],
          activeSlotId: 's1',
          onSelect: (_) {},
          onDelete: (_) {},
          activeLabel: 'ĐANG DÙNG',
          selectLabel: 'Chọn',
          deleteTooltip: 'Xoá ô lưu',
          deleteTitle: 'Xoá ô lưu?',
          deleteConfirmLabel: 'Xoá',
          deleteCancelLabel: 'Huỷ',
          deleteMessageBuilder: (name) => 'Xoá "$name" vĩnh viễn?',
        ),
      ),
    );
    expect(find.text('ĐANG DÙNG'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('Chọn'), findsOneWidget);
    final del = tester.widget<IconButton>(
      find.byKey(const ValueKey('saveSlotDeleteBtn_s2')),
    );
    expect(del.tooltip, 'Xoá ô lưu');
  });

  testWidgets('RetryErrorState copied toast and copy hint', (tester) async {
    await tester.pumpWidget(
      host(
        const RetryErrorState(
          message: 'Lỗi mạng',
          code: 'NET-1',
          copiedLabel: 'Đã sao chép',
          copyHintLabel: 'chạm để sao chép',
        ),
      ),
    );
    expect(
      semanticsLabeled('Diagnostic code NET-1, chạm để sao chép'),
      findsOneWidget,
    );
  });

  group('FEAT-203 group 2: headers, badges and claim links', () {
    final reward = MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x1',
    );

    testWidgets('AchievementRoadmapCard.claimLabel', (tester) async {
      await tester.pumpWidget(
        host(
          AchievementRoadmapCard(
            items: [
              AchievementRoadmapItem(
                id: 'a',
                title: 'Collect 10 items',
                description: 'Find items',
                progress: 10,
                target: 10,
                reward: reward,
              ),
            ],
            onClaim: (_) {},
            claimLabel: 'Nhận',
          ),
        ),
      );
      expect(find.text('Nhận'), findsOneWidget);
      expect(find.text('Claim'), findsNothing);
    });

    testWidgets('RewardTrackRoad.claimLabel and claimedLabel', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 320,
            child: RewardTrackRoad(
              tiers: [
                RewardTrackTier(
                  id: 't1',
                  requiredXp: 100,
                  freeReward: reward,
                  premiumReward: reward,
                ),
                RewardTrackTier(
                  id: 't2',
                  requiredXp: 200,
                  freeReward: reward,
                  premiumReward: reward,
                ),
              ],
              currentXp: 150,
              claimedFreeIds: const {'t1:free'},
              onClaim: (_, _) {},
              claimLabel: 'Nhận',
              claimedLabel: 'Đã nhận',
            ),
          ),
        ),
      );
      expect(find.text('Đã nhận'), findsWidgets);
      expect(find.text('Claimed'), findsNothing);
    });

    testWidgets('CraftingRecipeCard.materialsHeader', (tester) async {
      await tester.pumpWidget(
        host(
          CraftingRecipeCard(
            recipeId: 'r',
            title: 'Iron Shield',
            output: reward,
            ingredients: const [
              CraftingIngredient(
                itemId: 'iron',
                label: 'Iron',
                ownedQuantity: 5,
                requiredQuantity: 3,
              ),
            ],
            onCraft: () {},
            materialsHeader: 'Nguyên liệu',
          ),
        ),
      );
      expect(find.text('Nguyên liệu'), findsOneWidget);
      expect(find.text('Required Materials'), findsNothing);
    });

    testWidgets('UpgradePreviewPanel.costHeader', (tester) async {
      await tester.pumpWidget(
        host(
          UpgradePreviewPanel(
            title: 'Sword',
            currentLevel: 3,
            nextLevel: 4,
            statChanges: const [
              UpgradeStatChange(
                label: 'Attack',
                currentValue: '25',
                nextValue: '32',
                icon: Icons.flash_on_rounded,
              ),
            ],
            costs: const [
              UpgradeCost(
                label: 'Coins',
                currentAmount: 1000,
                requiredAmount: 750,
              ),
            ],
            onUpgrade: () {},
            costHeader: 'Chi phí nâng cấp',
          ),
        ),
      );
      expect(find.text('Chi phí nâng cấp'), findsOneWidget);
      expect(find.text('Upgrade Cost'), findsNothing);
    });

    testWidgets('VipPerkProgressRow.perksHeader', (tester) async {
      await tester.pumpWidget(
        host(
          VipPerkProgressRow(
            currentTier: 2,
            currentPoints: 300,
            nextTierPoints: 500,
            perks: const [VipPerk(icon: Icons.card_giftcard, label: 'Bonus')],
            onAction: () {},
            perksHeader: 'Đặc quyền',
          ),
        ),
      );
      expect(find.text('Đặc quyền'), findsOneWidget);
      expect(find.text('Perks & Privileges'), findsNothing);
    });

    testWidgets('TeamRosterList.youLabel', (tester) async {
      await tester.pumpWidget(
        host(
          TeamRosterList(
            members: const [
              TeamMemberItem(
                id: 'me',
                name: 'Me',
                role: TeamRole.leader,
                isSelf: true,
              ),
            ],
            onMemberTap: (_) {},
            youLabel: 'BẠN',
          ),
        ),
      );
      expect(find.text('BẠN'), findsOneWidget);
      expect(find.text('YOU'), findsNothing);
    });

    testWidgets('GuildContributionCard.retryLabel', (tester) async {
      await tester.pumpWidget(
        host(
          GuildContributionCard(
            guildName: 'Dragons',
            goalTitle: 'Weekly goal',
            totalContribution: 10,
            goalContribution: 100,
            memberContribution: 5,
            milestones: const [],
            onContribute: () {},
            onClaimMilestone: (_) {},
            errorMessage: 'Không tải được',
            onRetry: () async {},
            retryLabel: 'Thử lại',
          ),
        ),
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('CollectionAlbumPanel.viewRewardLabel', (tester) async {
      await tester.pumpWidget(
        host(
          CollectionAlbumPanel(
            title: 'Album',
            items: const [
              CollectionAlbumItem(
                id: 'c1',
                name: 'Crown',
                rarity: ItemRarity.rare,
                ownedCount: 1,
                requiredCount: 1,
              ),
            ],
            onItemTap: (_) {},
            completionRewardLabel: '100 gems',
            onViewReward: () {},
            viewRewardLabel: 'Xem thưởng',
          ),
        ),
      );
      expect(find.text('Xem thưởng'), findsOneWidget);
      expect(find.text('View Reward'), findsNothing);
    });

    testWidgets('StarChestProgressHud.openLabel', (tester) async {
      await tester.pumpWidget(
        host(
          StarChestProgressHud(
            currentStars: 20,
            targetStars: 20,
            onOpenChestTap: () {},
            openLabel: 'Mở!',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mở!'), findsOneWidget);
      expect(find.text('Open!'), findsNothing);
    });

    testWidgets('AppVersionGateOverlay.labels', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 400,
            child: AppVersionGateOverlay(
              decision: GateDecision.forceUpdate,
              config: const AppVersionGateConfig(),
              launchStore: (_) async => true,
              labels: const AppVersionGateLabels(
                requiredTitle: 'Bắt buộc cập nhật',
                updateNow: 'Cập nhật ngay',
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      expect(find.text('Bắt buộc cập nhật'), findsOneWidget);
      // CommonButton draws its label twice (stroke + fill).
      expect(find.text('Cập nhật ngay'), findsWidgets);
      expect(find.text('Cần cập nhật'), findsNothing);
    });

    testWidgets('ShimmerPlaceholder.semanticLabel', (tester) async {
      await tester.pumpWidget(
        host(const ShimmerPlaceholder(width: 50, semanticLabel: 'Đang tải')),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Đang tải',
        ),
        findsOneWidget,
      );
    });
  });
}
