import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/backup_restore_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/booster_slot_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_over_card_template.dart';
import 'package:roy_casual_kit/presentation/widgets/common/inventory_grid.dart';
import 'package:roy_casual_kit/presentation/widgets/common/leaderboard_list.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_path_map_tile.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_select_grid.dart';
import 'package:roy_casual_kit/presentation/widgets/common/quest_board_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/save_health_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/stacked_avatar_group.dart';
import 'package:roy_casual_kit/presentation/widgets/common/staggered_animated_grid.dart';
import 'package:roy_casual_kit/presentation/widgets/common/swipeable_action_tile.dart';
import 'package:roy_casual_kit/presentation/widgets/common/victory_card_template.dart';

import '../../support/golden_matrix.dart';
import '../../support/owned_storage.dart';
import 'golden_test_support.dart';

/// ENH-122 (batch E): level / list / board widgets. One golden per widget with
/// the interesting states stacked in one frame, rendered through the shared
/// matrix. Deterministic: every value is fixed, pulses are off, the one
/// entrance animation (`StaggeredAnimatedGrid`) is run with a zero stagger and
/// pumped to the end.
///
/// Not covered on purpose: `SwipeableActionTile` open state (needs a drag;
/// behavior tests own it), `BackupRestorePanel` mid-operation states.
void main() {
  final previous = installGoldenTolerance(
    'batch_e_level_list_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  Widget stack(List<Widget> children, {double width = 340}) => SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 760),
    Future<void> Function(WidgetTester)? afterPump,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: build()),
      ),
      goldenBaseName: name,
      guidelines: const [],
      afterPump: afterPump,
    );
  }

  testWidgets('LevelPathMapTile', (tester) async {
    await golden(
      tester,
      'levelpathmaptile_states',
      () => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          LevelPathMapTile(node: LevelPathNode(level: 1, state: LevelState.completed, starsEarned: 3)),
          LevelPathMapTile(node: LevelPathNode(level: 2, state: LevelState.completed, starsEarned: 1)),
          LevelPathMapTile(node: LevelPathNode(level: 3, state: LevelState.unlocked, isCurrent: true)),
          LevelPathMapTile(node: LevelPathNode(level: 4, state: LevelState.unlocked)),
          LevelPathMapTile(node: LevelPathNode(level: 5, state: LevelState.locked)),
          LevelPathMapTile(
            node: LevelPathNode(level: 128, state: LevelState.completed, starsEarned: 2),
            size: 72,
          ),
        ],
      ),
    );
  });

  testWidgets('LevelSelectGrid', (tester) async {
    await golden(
      tester,
      'levelselectgrid_states',
      () => SizedBox(
        width: 340,
        child: LevelSelectGrid(
          nodeSize: 56,
          spacing: 12,
          states: const [
            LevelState.completed,
            LevelState.completed,
            LevelState.completed,
            LevelState.unlocked,
            LevelState.locked,
            LevelState.locked,
            LevelState.locked,
            LevelState.locked,
          ],
          starsEarnedByLevel: const {1: 3, 2: 2, 3: 1},
        ),
      ),
    );
  });

  testWidgets('InventoryGrid', (tester) async {
    await golden(
      tester,
      'inventorygrid_states',
      () => SizedBox(
        width: 340,
        child: InventoryGrid(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          unlockedCapacity: 6,
          selectedSlotId: 2,
          snapshot: const InventorySnapshot(
            capacity: 8,
            slots: [
              InventorySlot(slotId: 1, itemId: 'potion', quantity: 3),
              InventorySlot(slotId: 2, itemId: 'sword', quantity: 1, equipped: true),
              InventorySlot(slotId: 3, itemId: 'gem', quantity: 120),
            ],
          ),
          itemBuilder: (context, slot, selected) => Container(
            decoration: BoxDecoration(
              color: selected ? Colors.amber : NeonTheme.cardAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${slot.itemId}\nx${slot.quantity}${slot.equipped ? '*' : ''}', textAlign: TextAlign.center),
          ),
          emptyBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: NeonTheme.cyan),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          lockedBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              color: NeonTheme.lockedFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_rounded),
          ),
        ),
      ),
    );
  });

  testWidgets('LeaderboardList', (tester) async {
    await golden(
      tester,
      'leaderboardlist_states',
      () => SizedBox(
        width: 340,
        child: LeaderboardList(
          entries: const [
            LeaderboardEntry(rank: 1, name: 'Aria', score: '12,450'),
            LeaderboardEntry(rank: 2, name: 'Bao', score: '11,200'),
            LeaderboardEntry(rank: 3, name: 'Chi', score: '9,870'),
            LeaderboardEntry(rank: 42, name: 'You', score: '1,200', highlighted: true),
            LeaderboardEntry(
              rank: 1000,
              name: 'A very long player name that must not break the row layout',
              score: '10',
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('QuestBoardPanel', (tester) async {
    await golden(
      tester,
      'questboardpanel_states',
      () => SizedBox(
        width: 340,
        child: QuestBoardPanel(
          onClaim: (_) {},
          quests: const [
            QuestViewModel(id: 'a', label: 'Win 3 levels', progress: 1, target: 3, claimed: false),
            QuestViewModel(id: 'b', label: 'Collect 50 stars', progress: 50, target: 50, claimed: false),
            QuestViewModel(id: 'c', label: 'Daily login', progress: 1, target: 1, claimed: true),
            QuestViewModel(id: 'd', label: 'Open a chest', progress: 1, target: 1, claimed: false, claiming: true),
          ],
        ),
      ),
    );
  });

  testWidgets('QuestBoardPanel empty', (tester) async {
    await golden(
      tester,
      'questboardpanel_empty',
      () => SizedBox(
        width: 340,
        child: QuestBoardPanel(onClaim: (_) {}, quests: const []),
      ),
    );
  });

  testWidgets('BoosterSlotBar', (tester) async {
    await golden(
      tester,
      'boosterslotbar_states',
      () => stack([
        BoosterSlotBar(
          onSlotTap: (_) {},
          onEmptySlotTap: (_) {},
          slots: [
            BoosterSlot(id: 'bomb', label: 'Bomb', count: 3),
            BoosterSlot(id: 'shuffle', label: 'Shuffle', count: 0),
            BoosterSlot(id: 'hammer', label: 'Hammer', count: 2, cooldown: const Duration(minutes: 5)),
            BoosterSlot(id: 'wild', label: 'Wild', count: 1, isLocked: true),
          ],
        ),
      ]),
    );
  });

  testWidgets('StackedAvatarGroup', (tester) async {
    Widget face(Color c) => Container(color: c);
    await golden(
      tester,
      'stackedavatargroup_states',
      () => stack([
        StackedAvatarGroup(items: [StackedAvatarItem.widget(face(Colors.red))]),
        StackedAvatarGroup(
          items: [
            StackedAvatarItem.widget(face(Colors.red)),
            StackedAvatarItem.widget(face(Colors.green)),
            StackedAvatarItem.widget(face(Colors.blue)),
          ],
        ),
        StackedAvatarGroup(
          maxAvatars: 3,
          onOverflowTap: () {},
          items: [
            for (final c in [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink])
              StackedAvatarItem.widget(face(c)),
          ],
        ),
      ]),
    );
  });

  testWidgets('StaggeredAnimatedGrid', (tester) async {
    await golden(
      tester,
      'staggeredanimatedgrid_done',
      () => SizedBox(
        width: 340,
        child: StaggeredAnimatedGrid(
          itemCount: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          stagger: Duration.zero,
          animationDuration: const Duration(milliseconds: 50),
          itemBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              color: Colors.primaries[i % Colors.primaries.length],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${i + 1}'),
          ),
        ),
      ),
      // One long pump is not enough: the delay Timer fires inside it but the
      // controller's ticker only starts on the NEXT frame, so a single
      // `pump(1s)` leaves every item at opacity 0 (an empty golden).
      afterPump: (t) async {
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });

  testWidgets('GameOverCardTemplate', (tester) async {
    await golden(
      tester,
      'gameovercardtemplate_states',
      () => stack([
        GameOverCardTemplate(
          title: 'Out of moves',
          message: 'So close!',
          icon: Icons.sentiment_dissatisfied,
          statLines: const ['Score: 4,200', 'Best: 6,000'],
          primaryActionLabel: 'Retry',
          onPrimaryAction: () {},
          secondaryActionLabel: 'Menu',
          onSecondaryAction: () {},
        ),
        GameOverCardTemplate(
          title: 'Game over',
          primaryActionLabel: 'Again',
          onPrimaryAction: () {},
        ),
      ]),
      // A 320ms fade-in starts on the frame AFTER the first pump: without this
      // every case is an empty (one-colour) image.
      afterPump: (t) async {
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });

  testWidgets('VictoryCardTemplate', (tester) async {
    await golden(
      tester,
      'victorycardtemplate_states',
      () => stack([
        VictoryCardTemplate(
          title: 'Level 12 cleared',
          statLines: const ['Score: 9,800', 'Combo: x6'],
          starsEarned: 3,
          starStaggerDuration: Duration.zero,
        ),
        VictoryCardTemplate(
          title: 'Level 13 cleared',
          statLines: const ['Score: 3,100'],
          starsEarned: 1,
          starStaggerDuration: Duration.zero,
        ),
      ]),
      afterPump: (t) async {
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
      },
    );
  });

  testWidgets('SaveHealthCard', (tester) async {
    final storage = await ownedStorage({'coins': 100});
    await golden(
      tester,
      'savehealthcard_states',
      () => stack([
        SaveHealthCard(storage: storage, secret: 'secret', nowMs: () => 1700000000000),
        SaveHealthCard(storage: storage, nowMs: () => 1700000000000),
      ]),
    );
  });

  testWidgets('BackupRestorePanel', (tester) async {
    final storage = await ownedStorage({'coins': 100});
    await golden(
      tester,
      'backuprestorepanel_idle',
      () => SizedBox(
        width: 340,
        child: BackupRestorePanel(
          secret: 'secret',
          storage: storage,
          onExport: (_) async {},
          onImport: () async => null,
        ),
      ),
    );
  });

  testWidgets('SwipeableActionTile', (tester) async {
    await golden(
      tester,
      'swipeableactiontile_closed',
      () => stack([
        SwipeableActionTile(
          enableHaptic: false,
          leadingActions: [SwipeableAction(label: 'Claim', icon: Icons.check, onTap: () {})],
          trailingActions: [SwipeableAction(label: 'Delete', icon: Icons.delete, color: Colors.red, onTap: () {})],
          child: Container(
            height: 64,
            color: NeonTheme.card,
            alignment: Alignment.center,
            child: const Text('Swipe me'),
          ),
        ),
      ]),
    );
  });
}
