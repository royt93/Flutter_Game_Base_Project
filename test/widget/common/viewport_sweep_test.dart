import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/core/inventory_service.dart' show InventorySlot, InventorySnapshot;

import 'package:roy_casual_kit/core/consent_state_service.dart'
    show ConsentStatus;
import 'package:roy_casual_kit/core/inventory_service.dart' show ItemRarity;

import '../../support/viewport_sweep.dart';

Widget _defaultSweepInventoryItemBuilder(
  BuildContext context,
  InventorySlot slot,
  bool isSelected,
) => Center(child: Text('${slot.itemId} x${slot.quantity}'));

/// FEAT-200 pha 1: each entry is a widget that must survive every default
/// viewport. Add new widgets here; unsupported ones need a reason in
/// [_allowlist].
void main() {
  group('FEAT-200 phase 2e: general display widgets', () {
    final cases = <String, Widget Function()>{
      'BadgeDot': () => const BadgeDot(size: 24),
      'CircularProgressRing': () => const CircularProgressRing(
        progress: 0.75,
        label: '75%',
      ),
      'CurrencyCounter': () => const CurrencyCounter(value: 123456),
      'ProgressBarStars': () => const ProgressBarStars(progress: 0.75),
      'StarRating': () => const StarRating(earned: 2),
      'PaginatedDotsIndicator': () => const PaginatedDotsIndicator(
        count: 8,
        currentIndex: 4,
      ),
      'SectionHeader': () => const SectionHeader(title: 'Daily rewards'),
      'CooldownCountdownChip': () => const CooldownCountdownChip(
        remaining: Duration(hours: 2, minutes: 30),
      ),
      'CountdownChip': () => CountdownChip(
        target: DateTime.now().add(const Duration(hours: 2, minutes: 30)),
      ),
      'NextRewardTeaserChip': () => NextRewardTeaserChip(
        rewardLabel: 'Epic chest',
        remainingText: '2h 30m',
        progress: 0.72,
        onTap: () {},
      ),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        await runViewportSweep(tester, entry.value);
      });

      testWidgets('${entry.key} at 2.0x text, 320dp and landscape', (tester) async {
        await runViewportSweep(
          tester,
          entry.value,
          viewports: const [
            ViewportCase('320x480', Size(320, 480)),
            ViewportCase('568x320-landscape', Size(568, 320)),
          ],
          textScale: 2.0,
        );
      });
    }
  });

  group('FEAT-200 phase 2q: booster and streak indicators', () {
    testWidgets('BoosterSlotBar', (tester) async {
      await runViewportSweep(
        tester,
        () => BoosterSlotBar(
          slots: [
            BoosterSlot(id: 'hammer', label: 'Hammer', count: 3),
            BoosterSlot(id: 'shield', label: 'Shield', count: 0),
            BoosterSlot(id: 'bomb', label: 'Bomb', count: 1),
          ],
          onSlotTap: (_) {},
          onEmptySlotTap: (_) {},
        ),
      );
    });

    testWidgets('BoosterSlotBar at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => BoosterSlotBar(
          slots: [
            BoosterSlot(id: 'hammer', label: 'Hammer', count: 3),
            BoosterSlot(id: 'shield', label: 'Shield', count: 0),
            BoosterSlot(id: 'bomb', label: 'Bomb', count: 1),
          ],
          onSlotTap: (_) {},
          onEmptySlotTap: (_) {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('StreakCounter', (tester) async {
      await runViewportSweep(tester, () => const StreakCounter(days: 14));
    });

    testWidgets('StreakCounter at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => const StreakCounter(days: 14),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('WinStreakFlameHud', (tester) async {
      await runViewportSweep(
        tester,
        () => WinStreakFlameHud(streakCount: 0, multiplierLabel: 'x1.0'),
      );
    });

    testWidgets('WinStreakFlameHud at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => WinStreakFlameHud(streakCount: 0, multiplierLabel: 'x1.0'),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2r: wheel, badges, analytics', () {
    testWidgets('CoinMultiplierWheel', (tester) async {
      await runViewportSweep(
        tester,
        () => CoinMultiplierWheel(autoStart: false),
      );
    });

    testWidgets('CoinMultiplierWheel at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => CoinMultiplierWheel(autoStart: false),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('BadgeShowcaseStrip', (tester) async {
      await runViewportSweep(
        tester,
        () => BadgeShowcaseStrip(
          slotCount: 4,
          badges: [
            BadgeShowcaseItem(id: 'first', label: 'First win'),
            BadgeShowcaseItem(id: 'streak', label: 'Seven-day streak'),
          ],
          onSlotTap: (_) {},
          readOnly: true,
        ),
      );
    });

    testWidgets('BadgeShowcaseStrip at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => BadgeShowcaseStrip(
          slotCount: 4,
          badges: [
            BadgeShowcaseItem(id: 'first', label: 'First win'),
            BadgeShowcaseItem(id: 'streak', label: 'Seven-day streak'),
          ],
          onSlotTap: (_) {},
          readOnly: true,
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('AnalyticsQueueStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => AnalyticsQueueStatusCard(
          snapshot: AnalyticsQueueSnapshot(
            pendingCount: 123,
            uploadedCount: 9876,
            droppedCounts: const {'Rate limited': 12, 'Rejected': 3},
          ),
          consentGranted: false,
        ),
      );
    });

    testWidgets('AnalyticsQueueStatusCard at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => AnalyticsQueueStatusCard(
          snapshot: AnalyticsQueueSnapshot(
            pendingCount: 123,
            uploadedCount: 9876,
            droppedCounts: const {'Rate limited': 12, 'Rejected': 3},
          ),
          consentGranted: false,
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2p: inventory and level path', () {
    testWidgets('InventoryGrid', (tester) async {
      await runViewportSweep(
        tester,
        () => InventoryGrid(
          snapshot: const InventorySnapshot(
            slots: [
              InventorySlot(slotId: 1, itemId: 'potion', quantity: 3),
              InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
            ],
            capacity: 4,
          ),
          itemBuilder: _defaultSweepInventoryItemBuilder,
          unlockedCapacity: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      );
    });

    testWidgets('InventoryGrid at 2.0x text, 320dp and landscape', (tester) async {
      await runViewportSweep(
        tester,
        () => InventoryGrid(
          snapshot: const InventorySnapshot(
            slots: [
              InventorySlot(slotId: 1, itemId: 'potion', quantity: 3),
              InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
            ],
            capacity: 4,
          ),
          itemBuilder: _defaultSweepInventoryItemBuilder,
          unlockedCapacity: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('LevelPathMapTile', (tester) async {
      await runViewportSweep(
        tester,
        () => Wrap(
          spacing: 12,
          children: [
            LevelPathMapTile(
              node: LevelPathNode(level: 3, state: LevelState.completed, starsEarned: 2),
              onTap: () {},
            ),
            LevelPathMapTile(
              node: LevelPathNode(level: 4, state: LevelState.unlocked, isCurrent: true),
              onTap: () {},
            ),
          ],
        ),
      );
    });

    testWidgets('LevelPathMapTile at 2.0x text, 320dp and landscape', (tester) async {
      await runViewportSweep(
        tester,
        () => Wrap(
          spacing: 12,
          children: [
            LevelPathMapTile(
              node: LevelPathNode(level: 3, state: LevelState.completed, starsEarned: 2),
              onTap: () {},
            ),
            LevelPathMapTile(
              node: LevelPathNode(level: 4, state: LevelState.unlocked, isCurrent: true),
              onTap: () {},
            ),
          ],
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2o: slider and daily offers', () {
    testWidgets('CandySlider', (tester) async {
      await runViewportSweep(
        tester,
        () => CandySlider(value: 0.55, onChanged: (_) {}),
      );
    });

    testWidgets('CandySlider at 2.0x text, 320dp and landscape', (tester) async {
      await runViewportSweep(
        tester,
        () => CandySlider(value: 0.55, onChanged: (_) {}),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('DailyOfferStack', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: DailyOfferStack(
            offers: const [
              DailyOffer(
                id: 'starter',
                title: 'Starter Pack',
                priceLabel: r'$1.99',
                subtitle: 'Great value for new players',
                badgeLabel: 'BEST VALUE',
              ),
              DailyOffer(
                id: 'coins',
                title: 'Coin Pouch',
                priceLabel: r'$0.99',
                subtitle: 'Limited time',
                icon: Icons.monetization_on_rounded,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      );
    });

    testWidgets('DailyOfferStack at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: DailyOfferStack(
            offers: const [
              DailyOffer(
                id: 'starter',
                title: 'Starter Pack',
                priceLabel: r'$1.99',
                subtitle: 'Great value for new players',
                badgeLabel: 'BEST VALUE',
              ),
              DailyOffer(
                id: 'coins',
                title: 'Coin Pouch',
                priceLabel: r'$0.99',
                subtitle: 'Limited time',
                icon: Icons.monetization_on_rounded,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2n: filters and content history', () {
    testWidgets('FilterChipRow', (tester) async {
      await runViewportSweep(
        tester,
        () => FilterChipRow<String>(
          filters: const [
            CandyFilter(value: 'rare', label: 'Rare collectibles'),
            CandyFilter(value: 'fire', label: 'Fire creatures'),
            CandyFilter(value: 'event', label: 'Event rewards'),
          ],
          selectedValues: const {'rare'},
          onChanged: (_) {},
        ),
      );
    });

    testWidgets('FilterChipRow at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => FilterChipRow<String>(
          filters: const [
            CandyFilter(value: 'rare', label: 'Rare collectibles'),
            CandyFilter(value: 'fire', label: 'Fire creatures'),
            CandyFilter(value: 'event', label: 'Event rewards'),
          ],
          selectedValues: const {'rare'},
          onChanged: (_) {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('ContentRevisionHistoryPanel', (tester) async {
      await runViewportSweep(
        tester,
        () => ContentRevisionHistoryPanel(
          revisions: [
            ContentRevisionSummary(
              revision: 'opaque-revision-v12',
              label: 'Winter event content update',
              version: 12,
              appliedAtText: 'Today, 10:30 UTC',
            ),
            ContentRevisionSummary(
              revision: 'opaque-revision-v11',
              label: 'New character release notes',
              version: 11,
              appliedAtText: 'Yesterday, 18:45 UTC',
            ),
          ],
          currentRevision: 'opaque-revision-v12',
          onRollback: (_) async {},
        ),
      );
    });

    testWidgets('ContentRevisionHistoryPanel at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => ContentRevisionHistoryPanel(
          revisions: [
            ContentRevisionSummary(
              revision: 'opaque-revision-v12',
              label: 'Winter event content update',
              version: 12,
              appliedAtText: 'Today, 10:30 UTC',
            ),
            ContentRevisionSummary(
              revision: 'opaque-revision-v11',
              label: 'New character release notes',
              version: 11,
              appliedAtText: 'Yesterday, 18:45 UTC',
            ),
          ],
          currentRevision: 'opaque-revision-v12',
          onRollback: (_) async {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2m: lists and goal indicators', () {
    testWidgets('FriendRequestTile', (tester) async {
      await runViewportSweep(
        tester,
        () => FriendRequestTile(
          request: FriendRequestItem(
            requestId: 'req-1',
            name: 'Maya Rose',
            subtitle: 'Level 42 · 3 mutual friends',
            mutualFriendsCount: 3,
            avatar: const Icon(Icons.face),
          ),
          onAccept: (_) {},
          onDecline: (_) {},
        ),
      );
    });

    testWidgets('FriendRequestTile at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => FriendRequestTile(
          request: FriendRequestItem(
            requestId: 'req-1',
            name: 'Maya Rose',
            subtitle: 'Level 42 · 3 mutual friends',
            mutualFriendsCount: 3,
            avatar: const Icon(Icons.face),
          ),
          onAccept: (_) {},
          onDecline: (_) {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('LevelGoalTracker', (tester) async {
      await runViewportSweep(
        tester,
        () => LevelGoalTracker(
          goals: [
            GoalItem(
              id: 'g1',
              label: 'Collect every coin in this level',
              icon: const Icon(Icons.monetization_on),
              current: 7,
              target: 10,
            ),
            GoalItem(
              id: 'g2',
              label: 'Finish without taking damage',
              icon: const Icon(Icons.shield),
              current: 1,
              target: 1,
            ),
          ],
        ),
      );
    });

    testWidgets('LevelGoalTracker at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => LevelGoalTracker(
          goals: [
            GoalItem(
              id: 'g1',
              label: 'Collect every coin in this level',
              icon: const Icon(Icons.monetization_on),
              current: 7,
              target: 10,
            ),
            GoalItem(
              id: 'g2',
              label: 'Finish without taking damage',
              icon: const Icon(Icons.shield),
              current: 1,
              target: 1,
            ),
          ],
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('QuestProgressPill', (tester) async {
      await runViewportSweep(
        tester,
        () => QuestProgressPill(completed: 4, total: 12, claimableCount: 2, onTap: () {}),
      );
    });

    testWidgets('QuestProgressPill at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => QuestProgressPill(completed: 4, total: 12, claimableCount: 2, onTap: () {}),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2l: calendar and avatar selection', () {
    testWidgets('DailyLoginCalendarWidget', (tester) async {
      await runViewportSweep(
        tester,
        () => DailyLoginCalendarWidget(
          currentStreakDay: 4,
          claimedDaysInCycle: const {1, 2, 3},
          canClaimToday: true,
          onClaim: () {},
        ),
      );
    });

    testWidgets('DailyLoginCalendarWidget at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => DailyLoginCalendarWidget(
          currentStreakDay: 4,
          claimedDaysInCycle: const {1, 2, 3},
          canClaimToday: true,
          onClaim: () {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('AvatarFrameSelector', (tester) async {
      await runViewportSweep(
        tester,
        () => AvatarFrameSelector(
          options: const [
            AvatarFrameOption(id: 'cyan', label: 'Classic Cyan', color: Colors.cyan),
            AvatarFrameOption(id: 'gold', label: 'Golden Legend', color: Colors.amber, locked: true),
            AvatarFrameOption(id: 'fire', label: 'Fire Streak', color: Colors.deepOrange),
          ],
          selectedId: 'cyan',
          onSelect: (_) {},
          previewChild: const Icon(Icons.person),
        ),
      );
    });

    testWidgets('AvatarFrameSelector at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => AvatarFrameSelector(
          options: const [
            AvatarFrameOption(id: 'cyan', label: 'Classic Cyan', color: Colors.cyan),
            AvatarFrameOption(id: 'gold', label: 'Golden Legend', color: Colors.amber, locked: true),
            AvatarFrameOption(id: 'fire', label: 'Fire Streak', color: Colors.deepOrange),
          ],
          selectedId: 'cyan',
          onSelect: (_) {},
          previewChild: const Icon(Icons.person),
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2k: compact controls', () {
    testWidgets('AsyncCommonButton', (tester) async {
      await runViewportSweep(
        tester,
        () => AsyncCommonButton(
          label: 'Save progress',
          onPressed: () async {},
        ),
      );
    });

    testWidgets('AsyncCommonButton at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => AsyncCommonButton(
          label: 'Save progress',
          onPressed: () async {},
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('CandySearchBar', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await runViewportSweep(
        tester,
        () => CandySearchBar(controller: controller, onChanged: (_) {}),
      );
    });

    testWidgets('CandySearchBar at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await runViewportSweep(
        tester,
        () => CandySearchBar(controller: controller, onChanged: (_) {}),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2j: simple controls and layout', () {
    final cases = <String, Widget Function()>{
      'TooltipBubble': () => TooltipBubble.text('Tap here'),
      'CommonListTile': () => const CommonListTile(
        title: 'Daily reward',
        subtitle: 'Claim your free coins',
        leading: Icon(Icons.card_giftcard),
      ),
      'SoundToggleFab': () => const SoundToggleFab(),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        await runViewportSweep(tester, entry.value);
      });

      testWidgets('${entry.key} at 2.0x text, 320dp and landscape', (
        tester,
      ) async {
        await runViewportSweep(
          tester,
          entry.value,
          viewports: const [
            ViewportCase('320x480', Size(320, 480)),
            ViewportCase('568x320-landscape', Size(568, 320)),
          ],
          textScale: 2.0,
        );
      });
    }
  });

  group('FEAT-200 phase 2i: static display components', () {
    testWidgets('ContrastPreviewCard', (tester) async {
      await runViewportSweep(
        tester,
        () => ContrastPreviewCard(
          foreground: Colors.white,
          background: Colors.black,
          sampleText: 'Readable sample',
        ),
      );
    });

    testWidgets('ContrastPreviewCard at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => ContrastPreviewCard(
          foreground: Colors.white,
          background: Colors.black,
          sampleText: 'Readable sample',
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('AvatarFrame', (tester) async {
      await runViewportSweep(
        tester,
        () => const AvatarFrame(child: Text('AB')),
      );
    });

    testWidgets('AvatarFrame at 2.0x text, 320dp and landscape', (tester) async {
      await runViewportSweep(
        tester,
        () => const AvatarFrame(child: Text('AB')),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('PanelCard', (tester) async {
      await runViewportSweep(
        tester,
        () => const PanelCard(child: Text('Reusable panel content')),
      );
    });

    testWidgets('PanelCard at 2.0x text, 320dp and landscape', (tester) async {
      await runViewportSweep(
        tester,
        () => const PanelCard(child: Text('Reusable panel content')),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2h: status cards', () {
    final cases = <String, Widget Function()>{
      'ContentPackStatusCard': () => ContentPackStatusCard(
        status: ContentPackStatus.ready,
        contentVersion: 12,
        updatedAtText: 'Today, 10:30 UTC',
      ),
      'DeepLinkResultCard': () => DeepLinkResultCard(
        status: DeepLinkResultStatus.rejected,
        summaryText: 'This request could not be opened.',
      ),
      'EconomyCertificateStatusCard': () => EconomyCertificateStatusCard(
        status: EconomyCertificateCardStatus.tampered,
        summaryText: 'Certificate verification failed.',
      ),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        await runViewportSweep(tester, entry.value);
      });

      testWidgets('${entry.key} at 2.0x text, 320dp and landscape', (
        tester,
      ) async {
        await runViewportSweep(
          tester,
          entry.value,
          viewports: const [
            ViewportCase('320x480', Size(320, 480)),
            ViewportCase('568x320-landscape', Size(568, 320)),
          ],
          textScale: 2.0,
        );
      });
    }
  });

  group('FEAT-200 phase 2g: display widgets', () {
    testWidgets('BatterySaverIndicator', (tester) async {
      await runViewportSweep(
        tester,
        () => BatterySaverIndicator(active: true, batteryPercent: 17),
      );
    });

    testWidgets('BatterySaverIndicator at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => BatterySaverIndicator(active: true, batteryPercent: 17),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });

    testWidgets('StackedAvatarGroup', (tester) async {
      await runViewportSweep(
        tester,
        () => StackedAvatarGroup(
          items: const [
            StackedAvatarItem.widget(Text('A')),
            StackedAvatarItem.widget(Text('B')),
            StackedAvatarItem.widget(Text('C')),
            StackedAvatarItem.widget(Text('D')),
            StackedAvatarItem.widget(Text('E')),
          ],
        ),
      );
    });

    testWidgets('StackedAvatarGroup at 2.0x text, 320dp and landscape', (
      tester,
    ) async {
      await runViewportSweep(
        tester,
        () => StackedAvatarGroup(
          items: const [
            StackedAvatarItem.widget(Text('A')),
            StackedAvatarItem.widget(Text('B')),
            StackedAvatarItem.widget(Text('C')),
            StackedAvatarItem.widget(Text('D')),
            StackedAvatarItem.widget(Text('E')),
          ],
        ),
        viewports: const [
          ViewportCase('320x480', Size(320, 480)),
          ViewportCase('568x320-landscape', Size(568, 320)),
        ],
        textScale: 2.0,
      );
    });
  });

  group('FEAT-200 phase 2f: static display panels', () {
    testWidgets('EmptyStatePlaceholder', (tester) async {
      await runViewportSweep(
        tester,
        () => EmptyStatePlaceholder(
          icon: Icons.emoji_events_outlined,
          title: 'No achievements yet',
          message: 'Complete a level to earn your first badge.',
          action: const Text('Play now'),
        ),
      );
    });

    testWidgets('EventSchemaAuditCard', (tester) async {
      await runViewportSweep(
        tester,
        () => EventSchemaAuditCard(
          snapshot: EventSchemaAuditSnapshot(
            totalValidations: 120,
            rejectedCount: 37,
            redactedCount: 24,
          ),
        ),
      );
    });
  });

  group('FEAT-200: viewport sweep', () {
    testWidgets('StreakRepairDialog', (tester) async {
      await runViewportSweep(
        tester,
        () =>
            StreakRepairDialog(streakDays: 14, onRepair: () {}, onSkip: () {}),
        targetFinder: find.byKey(const ValueKey('streakPanel')),
      );
    });

    testWidgets('StreakRepairDialog at 2.0x text', (tester) async {
      await runViewportSweep(
        tester,
        () =>
            StreakRepairDialog(streakDays: 14, onRepair: () {}, onSkip: () {}),
        targetFinder: find.byKey(const ValueKey('streakPanel')),
        textScale: 2.0,
      );
    });

    testWidgets('PrestigeConfirmationCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: PrestigeConfirmationCard(
            currentLevel: 50,
            requiredPrestigeValue: 'Level 50',
            currentMultiplier: 1.0,
            nextMultiplier: 1.5,
            rewards: const [
              PrestigeReward(
                icon: Icons.flash_on_rounded,
                label: 'Permanent Speed',
                amount: '+25%',
              ),
            ],
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
        targetFinder: find.byType(PrestigeConfirmationCard),
      );
    });

    testWidgets('RewardPopup', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: RewardPopup(
            title: 'Daily reward',
            message: 'You earned 100 gems',
            icon: Icons.diamond_rounded,
            enableParticles: false,
            onDismiss: () {},
          ),
        ),
        targetFinder: find.byType(RewardPopup),
      );
    });

    testWidgets('SupportDiagnosticsCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: SupportDiagnosticsCard(
            summary: SupportDiagnosticsSummary(
              appVersion: '1.2.3',
              generatedAtText: '10:30 UTC',
              sections: const ['health', 'logs'],
            ),
            onShare: () async {},
          ),
        ),
        targetFinder: find.byType(SupportDiagnosticsCard),
      );
    });

    testWidgets('GameOverCardTemplate', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: GameOverCardTemplate(
            title: 'Game Over',
            message: 'Better luck next time',
            statLines: const ['Score 12,340', 'Best 20,000', 'Combo x7'],
            primaryActionLabel: 'Retry',
            onPrimaryAction: () {},
            secondaryActionLabel: 'Home',
            onSecondaryAction: () {},
          ),
        ),
        targetFinder: find.byType(GameOverCardTemplate),
      );
    });

    testWidgets('VictoryCardTemplate', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: VictoryCardTemplate(
            title: 'Level Complete',
            statLines: const ['Score 12,340', 'Moves 18'],
            starsEarned: 3,
          ),
        ),
        targetFinder: find.byType(VictoryCardTemplate),
      );
    });

    testWidgets('StreakShieldCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: StreakShieldCard(
            streakDays: 14,
            shieldCount: 2,
            onUseShield: () {},
            onRepair: () {},
            onDismiss: () {},
          ),
        ),
        targetFinder: find.byType(StreakShieldCard),
      );
    });

    testWidgets('MilestoneCelebrationDialog', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: MilestoneCelebrationDialog(
            level: 50,
            rewards: [
              MilestoneReward(
                icon: Icons.diamond_rounded,
                label: 'Gems',
                amountLabel: '+100',
              ),
              MilestoneReward(icon: Icons.bolt_rounded, label: 'Energy'),
            ],
            onClaim: () {},
          ),
        ),
        targetFinder: find.byType(MilestoneCelebrationDialog),
      );
    });

    testWidgets('CloudSaveStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: CloudSaveStatusCard(status: CloudSaveStatus.error),
        ),
        targetFinder: find.byType(CloudSaveStatusCard),
      );
    });

    testWidgets('ConnectivityStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: ConnectivityStatusCard(
            state: ConnectivityCardState.degraded,
            queuedCount: 12,
          ),
        ),
        targetFinder: find.byType(ConnectivityStatusCard),
      );
    });

    testWidgets('OutboxQueueStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: OutboxQueueStatusCard(
            pendingCount: 12,
            manualReviewCount: 3,
            status: OutboxQueueStatus.draining,
          ),
        ),
        targetFinder: find.byType(OutboxQueueStatusCard),
      );
    });

    testWidgets('AnnouncementPreviewCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: AnnouncementPreviewCard(
            messageText: 'Maintenance tonight from 02:00 to 04:00 UTC',
            localeLabel: 'English',
          ),
        ),
        targetFinder: find.byType(AnnouncementPreviewCard),
      );
    });

    testWidgets('FlashSaleOfferCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: FlashSaleOfferCard(
            title: 'Starter pack',
            priceLabel: '\$1.99',
            discountPercent: 60,
            expiresAt: DateTime.now().add(const Duration(hours: 5)),
            onBuyTap: () {},
          ),
        ),
        targetFinder: find.byType(FlashSaleOfferCard),
      );
    });

    testWidgets('ComebackBundleCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: ComebackBundleCard(
            title: 'Welcome back!',
            body: 'We saved a gift for you while you were away.',
            absenceLabel: '7 days away',
            rewards: [
              MilestoneReward(
                icon: Icons.diamond_rounded,
                label: 'Gems',
                amountLabel: '+100',
              ),
            ],
            onClaim: () {},
          ),
        ),
        targetFinder: find.byType(ComebackBundleCard),
      );
    });

    testWidgets('RankPromotionDialog', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: RankPromotionDialog(
            fromTier: LeaderboardTier.silver,
            toTier: LeaderboardTier.gold,
            onContinue: () {},
          ),
        ),
        targetFinder: find.byType(RankPromotionDialog),
      );
    });

    // 2.0x text is the harshest common accessibility setting: every widget
    // that fits at 1.0x must still not overflow at 320dp.
    group('2.0x text scale at 320dp and landscape', () {
      const tight = [
        ViewportCase('320x480', Size(320, 480)),
        ViewportCase('568x320-landscape', Size(568, 320)),
      ];
      final cases = <String, Widget Function()>{
        'CloudSaveStatusCard': () =>
            CloudSaveStatusCard(status: CloudSaveStatus.error),
        'ConnectivityStatusCard': () => ConnectivityStatusCard(
          state: ConnectivityCardState.degraded,
          queuedCount: 12,
        ),
        'OutboxQueueStatusCard': () => OutboxQueueStatusCard(
          pendingCount: 12,
          manualReviewCount: 3,
          status: OutboxQueueStatus.draining,
        ),
        'AnnouncementPreviewCard': () => AnnouncementPreviewCard(
          messageText: 'Maintenance tonight from 02:00 to 04:00 UTC',
          localeLabel: 'English',
        ),
        'GameOverCardTemplate': () => GameOverCardTemplate(
          title: 'Game Over',
          statLines: const ['Score 12,340', 'Best 20,000'],
          primaryActionLabel: 'Retry',
          onPrimaryAction: () {},
          secondaryActionLabel: 'Home',
          onSecondaryAction: () {},
        ),
        'StreakShieldCard': () => StreakShieldCard(
          streakDays: 14,
          shieldCount: 2,
          onUseShield: () {},
          onRepair: () {},
          onDismiss: () {},
        ),
      };
      for (final e in cases.entries) {
        testWidgets(e.key, (tester) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
            viewports: tight,
            textScale: 2.0,
          );
        });
      }
    });

    group('FEAT-200 phase 2c: shop, status and banner widgets', () {
      final cases = <String, Widget Function()>{
        'ShopItemCard': () => ShopItemCard(
          icon: Icons.diamond_rounded,
          title: 'Mega Gem Pack with a rather long title',
          priceLabel: '\$19.99',
          ribbonText: '-60%',
          onBuy: () {},
        ),
        'EnergyBar': () => const EnergyBar(
          currentEnergy: 3,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration(minutes: 12, seconds: 5),
        ),
        'OfflineEarningsPopup': () => OfflineEarningsPopup(
          coins: 123456,
          elapsed: const Duration(hours: 7, minutes: 30),
          onCollect: () {},
          onDoubleTap: () {},
        ),
        'PrestigeReadinessCard': () => PrestigeReadinessCard(
          current: 40,
          threshold: 50,
          multiplierText: 'x1.5',
          onPrestige: () {},
        ),
        'SeasonEventBanner': () => SeasonEventBanner(
          title: 'Winter Festival with a long event name',
          endsAt: DateTime.now().add(const Duration(days: 3)),
          progress: 0.4,
          subtitle: 'Collect snowflakes',
          onTap: () {},
        ),
        'TieredLeaderboardRow': () => TieredLeaderboardRow(
          rank: 12,
          playerName: 'A very long player name that must truncate',
          score: '1,234,567',
          tier: LeaderboardTier.gold,
        ),
        'VipPerkProgressRow': () => VipPerkProgressRow(
          currentTier: 2,
          currentPoints: 300,
          nextTierPoints: 500,
          perks: const [
            VipPerk(icon: Icons.card_giftcard, label: 'Daily bonus'),
            VipPerk(icon: Icons.palette, label: 'Exclusive skins'),
          ],
          onAction: () {},
        ),
        'InboxMessageCard': () => InboxMessageCard(
          title: 'Weekend reward',
          body: 'Thanks for playing! Here is a gift for you, valid this week.',
          receivedLabel: '2h ago',
          onOpen: () {},
        ),
        'RewardedAdResultCard': () => RewardedAdResultCard(
          status: RewardedAdStatus.rewarded,
          rewardText: '+50 coins',
          onWatch: () async {},
        ),
        'SyncStatusCard': () => SyncStatusCard(
          status: SyncStatus.failed,
          lastSyncedText: '5 minutes ago',
          onSync: () async {},
        ),
        'PlayerDataRightsPanel': () =>
            PlayerDataRightsPanel(onExport: () async {}, onErase: () async {}),
        'ToastBanner': () =>
            const ToastBanner(message: 'Saved to the cloud successfully'),
      };
      for (final e in cases.entries) {
        testWidgets(e.key, (tester) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
          );
        });
        testWidgets('${e.key} at 2.0x text, 320dp and landscape', (
          tester,
        ) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
            viewports: const [
              ViewportCase('320x480', Size(320, 480)),
              ViewportCase('568x320-landscape', Size(568, 320)),
            ],
            textScale: 2.0,
          );
        });
      }
    });

    group('FEAT-200 phase 2d: panels and lists', () {
      final cases = <String, Widget Function()>{
        'QuestBoardPanel': () => QuestBoardPanel(
          quests: const [
            QuestViewModel(
              id: 'q1',
              label: 'Win three matches in a row without using any boosters',
              progress: 2,
              target: 3,
              claimed: false,
            ),
            QuestViewModel(
              id: 'q2',
              label: 'Collect 500 coins',
              progress: 500,
              target: 500,
              claimed: false,
            ),
          ],
          onClaim: (_) {},
        ),
        'RewardChoicePanel': () => RewardChoicePanel(
          options: const [
            RewardChoiceOption(id: 'a', label: 'Mega gem pack of one hundred'),
            RewardChoiceOption(id: 'b', label: 'Energy refill'),
          ],
          onConfirm: (_) async {},
        ),
        'ProfileStatsCard': () => ProfileStatsCard(
          name: 'A player with a quite long display name',
          avatar: const CircleAvatar(child: Text('AP')),
          level: ProfileLevel(level: 42, currentXp: 120, xpForNextLevel: 300),
          stats: [
            ProfileStat(label: 'Wins', valueText: '1,234'),
            ProfileStat(label: 'Best streak', valueText: '27'),
            ProfileStat(label: 'Playtime', valueText: '120h 30m'),
          ],
          onTap: () {},
        ),
        'CheckpointResumeCard': () => CheckpointResumeCard(
          checkpoint: CheckpointSummary(
            revision: 'r1',
            savedAtText: 'Today 10:30',
            progressText: 'Level 12, 3 stars',
          ),
          onResume: (_) async {},
          onStartNew: (_) async {},
        ),
        'EventCalendarCard': () => EventCalendarCard(
          events: const [
            EventCalendarItem(
              id: 'e1',
              dayLabel: 'Fri',
              title: 'Double rewards weekend with a long event title',
              timeLabel: '10:00 - 22:00',
              status: EventCalendarStatus.active,
            ),
          ],
          onOpen: (_) {},
        ),
        'GiftLivesRequestCard': () => GiftLivesRequestCard(
          request: const GiftLivesRequest(
            requestId: 'r1',
            senderName: 'A friend with a very long display name',
          ),
          onSendLife: (_) {},
        ),
        'TeamRosterList': () => TeamRosterList(
          members: const [
            TeamMemberItem(
              id: 'm1',
              name: 'A very long team member display name',
              role: TeamRole.leader,
            ),
            TeamMemberItem(id: 'm2', name: 'Bob', role: TeamRole.member),
          ],
          onMemberTap: (_) {},
          onPromote: (_) {},
          onKick: (_) {},
        ),
        'CollectionAlbumPanel': () => CollectionAlbumPanel(
          title: 'Mythic album with a long title',
          items: const [
            CollectionAlbumItem(
              id: 'c1',
              name: 'Moon crown',
              rarity: ItemRarity.legendary,
              ownedCount: 1,
              requiredCount: 1,
            ),
            CollectionAlbumItem(
              id: 'c2',
              name: 'Sun amulet',
              rarity: ItemRarity.rare,
              ownedCount: 0,
              requiredCount: 2,
            ),
          ],
          onItemTap: (_) {},
        ),
        'BackupRestorePanel': () => BackupRestorePanel(
          secret: 'k',
          onExport: (_) async {},
          onImport: () async => null,
        ),
        'ReminderPreferencesPanel': () => ReminderPreferencesPanel(
          intervalOptions: [
            ReminderIntervalOption(id: '1', label: 'Every day'),
            ReminderIntervalOption(id: '2', label: 'Every two days'),
          ],
          enabled: true,
          selectedId: '1',
          onChanged: (_, _) async {},
        ),
        'ConsentPreferencesPanel': () => ConsentPreferencesPanel(
          items: [
            ConsentPreferenceItem(
              id: 'analytics',
              label: 'Analytics',
              description:
                  'Help us improve the game by sharing anonymous usage data.',
              status: ConsentStatus.unknown,
            ),
          ],
          onChanged: (_, _) async {},
        ),
      };
      for (final e in cases.entries) {
        testWidgets(e.key, (tester) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
          );
        });
        testWidgets('${e.key} at 2.0x text, 320dp and landscape', (
          tester,
        ) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
            viewports: const [
              ViewportCase('320x480', Size(320, 480)),
              ViewportCase('568x320-landscape', Size(568, 320)),
            ],
            textScale: 2.0,
          );
        });
      }
    });
  });
}
