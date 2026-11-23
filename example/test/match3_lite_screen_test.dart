import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:roy_casual_kit_example/game/match3_boosters.dart';
import 'package:roy_casual_kit_example/screens/match3_lite_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCloud implements CloudSaveProvider {
  Map<String, Object?>? data;
  int uploads = 0;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> upload(Map<String, Object?> data) async {
    uploads++;
    this.data = Map.of(data);
  }

  @override
  Future<Map<String, Object?>?> download() async =>
      data == null ? null : Map.of(data!);
}

Widget _wrap({CloudSaveProvider? cloud}) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en'),
  fallbackLocale: AppTranslations.fallback,
  home: Match3LiteScreen(cloudProvider: cloud),
);

void main() {
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
    Get.put(EnergyService(maxEnergy: 3), permanent: true);
    Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    Get.put(DailyQuestService(), permanent: true);
    Get.put(AchievementService(), permanent: true);
    Get.put(LocalScoreboardService(capacity: 20), permanent: true);
  });

  testWidgets(
    'screen displays game HUD, start consumes energy once, blocked when empty',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(Match3LiteScreen), findsOneWidget);
      expect(find.text('Energy 3'), findsOneWidget);

      final startButton = find.byType(CommonButton).first;
      await tester.ensureVisible(startButton);
      await tester.pump();
      await tester.tap(startButton);
      await tester.pump();
      expect(find.text('Energy 2'), findsOneWidget);
    },
  );

  testWidgets('insufficient energy prevents starting a run', (tester) async {
    Get.find<EnergyService>().consumeEnergy(3);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final startButton = find.byType(CommonButton).first;
    await tester.ensureVisible(startButton);
    await tester.pump();
    await tester.tap(startButton);
    await tester.pump();
    expect(find.text('Not enough energy. Wait for refill.'), findsOneWidget);
  });

  testWidgets(
    'sync keeps higher cloud best score without dropping active run data',
    (tester) async {
      final board = List.generate(
        Match3Config.classic.cellCount,
        (index) =>
            (index + index ~/ Match3Config.classic.width) %
            Match3Config.classic.tileKinds,
      );
      final cloud = _TestCloud()
        ..data = {
          'schemaVersion': 2,
          'syncedAtMs': 0,
          'level': 1,
          'highestUnlockedLevel': 3,
          'bestScore': 900,
          'board': board,
          'score': 0,
          'moves': 20,
          'status': 'ready',
          'runActive': false,
          'rewarded': false,
          'runId': 1,
        };
      await tester.pumpWidget(_wrap(cloud: cloud));
      await tester.pump();
      final syncButton = find
          .ancestor(
            of: find.text('Sync Save').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(syncButton);
      await tester.pump();
      await tester.tap(syncButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Best 900'), findsOneWidget);
      expect(find.text('Save synced. Best score kept.'), findsOneWidget);
      expect(cloud.data?['bestScore'], 900);
      expect(cloud.data?['highestUnlockedLevel'], 3);
    },
  );

  testWidgets('win grants wallet, quest, achievement, and scoreboard once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      score: 1170,
      random: math.Random(2),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    Get.find<DailyQuestService>().incrementProgress('match3_win_daily', 2);
    final startButton = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_9')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(game.status, Match3Status.won);
    expect(Get.find<EconomyWallet>().balanceOf('coins'), 25);
    expect(Get.find<EconomyWallet>().balanceOf('gems'), 20);
    expect(Get.find<DailyQuestService>().progressOf('match3_win_daily'), 3);
    expect(
      Get.find<AchievementService>().isCompleted('match3_first_win'),
      isTrue,
    );
    expect(Get.find<LocalScoreboardService>().topN(1), hasLength(1));
    expect(Get.find<DailyQuestService>().isClaimed('match3_win_daily'), isTrue);
  });

  testWidgets('claimed daily quest reward is not granted on later wins', (
    tester,
  ) async {
    Get.find<DailyQuestService>().register('match3_win_daily', 1);
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      score: 1170,
      random: math.Random(2),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    Get.find<DailyQuestService>().incrementProgress('match3_win_daily', 3);
    Get.find<DailyQuestService>().claim('match3_win_daily');
    final start = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(Get.find<EconomyWallet>().balanceOf('gems'), 0);
    expect(Get.find<DailyQuestService>().isClaimed('match3_win_daily'), isTrue);
  });

  testWidgets('legacy v1 save migrates active run to level one without loss', (
    tester,
  ) async {
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    await StorageService.to.setString(
      'match3_lite_save_v1',
      jsonEncode({
        'schemaVersion': 1,
        'bestScore': 120,
        'board': board,
        'score': 80,
        'moves': 17,
        'status': 'playing',
        'runActive': true,
        'rewarded': false,
        'runId': 101,
      }),
    );
    Get.find<EnergyService>().consumeEnergy(1);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.text('Level 1/5'), findsOneWidget);
    expect(find.text('Open 1/5'), findsOneWidget);
    expect(find.text('Score 80'), findsOneWidget);
    expect(find.text('Moves 17'), findsOneWidget);
    expect(find.text('Energy 2'), findsOneWidget);
    final stored =
        jsonDecode(StorageService.to.getString('match3_lite_save_v1')!)
            as Map<String, dynamic>;
    expect(stored['board'], board);
    expect(stored['score'], 80);
    expect(stored['moves'], 17);
  });

  testWidgets('cascade animation blocks another swap until sequence settles', (
    tester,
  ) async {
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(initialBoard: board, random: math.Random(9));
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    final start = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 200));
    final initialMoves = game.moves;
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    await tester.pump();
    expect(game.moves, initialMoves - 1);
    await tester.tap(
      find.byKey(const ValueKey('match3_tile_10')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(game.moves, initialMoves - 1);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.moves, initialMoves - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen restores persisted active board without charging again', (
    tester,
  ) async {
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    await StorageService.to.setString(
      'match3_lite_save_v2',
      jsonEncode({
        'schemaVersion': 2,
        'level': 1,
        'highestUnlockedLevel': 1,
        'bestScore': 120,
        'board': board,
        'score': 80,
        'moves': 17,
        'status': 'playing',
        'runActive': true,
        'rewarded': false,
        'runId': 99,
      }),
    );
    Get.find<EnergyService>().consumeEnergy(1);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.text('Energy 2'), findsOneWidget);
    expect(find.text('Score 80'), findsOneWidget);
    expect(find.text('Moves 17'), findsOneWidget);
    expect(find.text('Level 1/5'), findsOneWidget);
    expect(find.text('Open 1/5'), findsOneWidget);
    expect(find.text('Start Run (-1 Energy)'), findsNWidgets(2));
  });

  testWidgets(
    'malformed persisted board does not resume without charging energy',
    (tester) async {
      await StorageService.to.setString(
        'match3_lite_save_v1',
        jsonEncode({
          'schemaVersion': 1,
          'bestScore': 120,
          'board': List<int>.filled(36, 0),
          'score': 80,
          'moves': 17,
          'status': 'playing',
          'runActive': true,
          'rewarded': false,
          'runId': 77,
        }),
      );
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Energy 3'), findsOneWidget);
      expect(find.text('Start Run (-1 Energy)'), findsNWidgets(2));
    },
  );

  testWidgets('level 1 win unlocks level 2 and next level spends energy once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      score: 1170,
      random: math.Random(22),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    final start = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.status, Match3Status.won);
    expect(find.text('Level 1/5'), findsOneWidget);
    expect(find.text('Open 2/5'), findsOneWidget);
    expect(find.text('Next Level (-1 Energy)'), findsNWidgets(2));
    final energyAfterWin = Get.find<EnergyService>().currentEnergy;
    final next = find
        .ancestor(
          of: find.text('Next Level (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(next);
    await tester.pump();
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Level 2/5'), findsOneWidget);
    expect(find.text('Goal 1370'), findsOneWidget);
    expect(find.text('Moves 20'), findsOneWidget);
    expect(Get.find<EnergyService>().currentEnergy, energyAfterWin - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loss records playtest aggregate once', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      moves: 1,
      status: Match3Status.playing,
      random: math.Random(23),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    final start = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.status, Match3Status.lost);
    final stored =
        jsonDecode(StorageService.to.getString('match3_playtest_telemetry_v1')!)
            as Map<String, dynamic>;
    final level1 = (stored['levels'] as Map)['1'] as Map;
    expect(level1['plays'], 1);
    expect(level1['wins'], 0);
    expect(level1['losses'], 1);
    expect(level1['totalMovesUsed'], 20);
  });

  testWidgets('win records anonymous playtest aggregate once and copies it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await StorageService.to.setString(
      'match3_playtest_telemetry_v1',
      jsonEncode({
        'schemaVersion': 1,
        'levels': {
          '1': {
            'plays': 2,
            'wins': 1,
            'losses': 1,
            'totalScore': 700,
            'totalMovesUsed': 30,
          },
        },
      }),
    );
    final board = List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      score: 1170,
      random: math.Random(22),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: AppTranslations.fallback,
        home: Match3LiteScreen(engine: game),
      ),
    );
    await tester.pump();
    final start = find
        .ancestor(
          of: find.text('Start Run (-1 Energy)').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
    await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.status, Match3Status.won);

    final stored =
        jsonDecode(StorageService.to.getString('match3_playtest_telemetry_v1')!)
            as Map<String, dynamic>;
    final level1 = (stored['levels'] as Map)['1'] as Map;
    expect(level1['plays'], 3);
    expect(level1['wins'], 2);
    expect(level1['losses'], 1);
    expect(level1['totalMovesUsed'], 31);

    final copy = find
        .ancestor(
          of: find.text('Copy Playtest Report').first,
          matching: find.byType(CommonButton),
        )
        .first;
    await tester.ensureVisible(copy);
    await tester.pump();
    await tester.tap(copy);
    await tester.pump(const Duration(milliseconds: 100));
    final report = jsonDecode(copied!) as Map<String, dynamic>;
    final copiedLevel1 = (report['levels'] as Map)['1'] as Map;
    expect(copiedLevel1['winRate'], closeTo(2 / 3, 1e-9));
    expect(report.keys.toSet(), {'schemaVersion', 'levels'});
    expect(copiedLevel1.keys.toSet(), {
      'plays',
      'wins',
      'losses',
      'totalScore',
      'totalMovesUsed',
      'winRate',
      'averageScore',
      'averageMovesUsed',
    });
    expect(find.text('Playtest report copied.'), findsOneWidget);
    expect(copied, isNot(contains('runId')));
  });

  testWidgets('screen fits compact viewport and has accessible tile labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'Tile row 1 column 1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  group('boosters', () {
    List<int> flatBoard() => List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );

    Future<Match3Engine> openRunning(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = Match3Engine(
        initialBoard: flatBoard(),
        random: math.Random(2),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en'),
          fallbackLocale: AppTranslations.fallback,
          home: Match3LiteScreen(engine: game),
        ),
      );
      await tester.pump();
      return game;
    }

    Future<void> start(WidgetTester tester) async {
      final startButton = find
          .ancestor(
            of: find.text('Start Run (-1 Energy)').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pump(const Duration(milliseconds: 300));
    }

    InventoryService inventory() => Get.find<InventoryService>();

    Finder slotTap(String id) => find.byKey(ValueKey('boosterSlotTap_$id'));

    testWidgets('starter boosters are granted once and shown on the bar', (
      tester,
    ) async {
      await openRunning(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('match3_booster_bar')), findsOneWidget);
      for (final id in match3BoosterItemIds.values) {
        expect(inventory().snapshot.value.quantityOf(id), 1);
      }
      // Opening the screen again must not grant a second starter set.
      await grantStarterBoosters(inventory());
      expect(inventory().snapshot.value.quantityOf('booster_bomb'), 1);
    });

    testWidgets('armed bomb clears an area, uses one booster, no move', (
      tester,
    ) async {
      final game = await openRunning(tester);
      await start(tester);
      final movesBefore = game.moves;
      await tester.tap(slotTap('booster_bomb'));
      await tester.pump();
      expect(find.text('Pick a tile for Bomb.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_14')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_14')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(game.score, greaterThan(0));
      expect(game.moves, movesBefore);
      expect(inventory().snapshot.value.quantityOf('booster_bomb'), 0);
      expect(inventory().snapshot.value.quantityOf('booster_row'), 1);
    });

    testWidgets('two boosters in one run each cost one from stock', (
      tester,
    ) async {
      await openRunning(tester);
      await start(tester);
      for (final id in ['booster_row', 'booster_column']) {
        await tester.tap(slotTap(id));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey('match3_tile_14')),
        );
        await tester.tap(find.byKey(const ValueKey('match3_tile_14')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(inventory().snapshot.value.quantityOf('booster_row'), 0);
      expect(inventory().snapshot.value.quantityOf('booster_column'), 0);
      expect(inventory().snapshot.value.quantityOf('booster_bomb'), 1);
    });

    testWidgets('tapping the armed booster again cancels it free of charge', (
      tester,
    ) async {
      final game = await openRunning(tester);
      await start(tester);
      await tester.tap(slotTap('booster_row'));
      await tester.pump();
      await tester.tap(slotTap('booster_row'));
      await tester.pump();
      expect(find.text('Booster cancelled.'), findsOneWidget);
      expect(inventory().snapshot.value.quantityOf('booster_row'), 1);

      // After cancelling, a normal tap selects a tile instead of firing.
      await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_0')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_0')));
      await tester.pump();
      expect(game.score, 0);
    });

    testWidgets('boosters are locked until the run is started', (tester) async {
      final game = await openRunning(tester);
      await tester.tap(slotTap('booster_bomb'));
      await tester.pump();
      expect(find.text('Pick a tile for Bomb.'), findsNothing);
      expect(inventory().snapshot.value.quantityOf('booster_bomb'), 1);
      expect(game.score, 0);
    });

    testWidgets('empty slot buys with coins; too few coins buys nothing', (
      tester,
    ) async {
      await openRunning(tester);
      await start(tester);
      // Use up the starter row booster so the slot is empty.
      await tester.tap(slotTap('booster_row'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('match3_tile_14')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(inventory().snapshot.value.quantityOf('booster_row'), 0);

      // No coins: buy must fail and change nothing.
      await tester.tap(slotTap('booster_row'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Not enough coins (30 needed).'), findsOneWidget);
      expect(inventory().snapshot.value.quantityOf('booster_row'), 0);
      expect(Get.find<EconomyWallet>().balanceOf('coins'), 0);

      // With coins: pays exactly the price and grants exactly one.
      await Get.find<EconomyWallet>().earn(
        currency: 'coins',
        amount: 100,
        transactionId: 'test_seed',
      );
      await tester.tap(slotTap('booster_row'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(inventory().snapshot.value.quantityOf('booster_row'), 1);
      expect(Get.find<EconomyWallet>().balanceOf('coins'), 70);
      expect(find.text('Bought 1 Row for 30 coins.'), findsOneWidget);
    });
  });

  group('level select and stars', () {
    List<int> flatBoard() => List.generate(
      Match3Config.classic.cellCount,
      (index) =>
          (index + index ~/ Match3Config.classic.width) %
          Match3Config.classic.tileKinds,
    );

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> seedSave(Map<String, Object?> data) async {
      await StorageService.to.setString(
        'match3_lite_save_v2',
        jsonEncode(data),
      );
    }

    Map<String, Object?> saved() {
      final raw = StorageService.to.getString('match3_lite_save_v2')!;
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    }

    testWidgets('stars rule: moves left thresholds and bad limits', (_) async {
      expect(match3StarsFor(movesLeft: 8, moveLimit: 20), 3);
      expect(match3StarsFor(movesLeft: 7, moveLimit: 20), 2);
      expect(match3StarsFor(movesLeft: 3, moveLimit: 20), 2);
      expect(match3StarsFor(movesLeft: 2, moveLimit: 20), 1);
      expect(match3StarsFor(movesLeft: 0, moveLimit: 20), 1);
      expect(match3StarsFor(movesLeft: 99, moveLimit: 20), 3);
      expect(
        () => match3StarsFor(movesLeft: 1, moveLimit: 0),
        throwsArgumentError,
      );
    });

    testWidgets('saved stars are read defensively and merged by max', (
      _,
    ) async {
      final read = match3ReadBestStars({
        '1': 3,
        '2': 9,
        '3': 'x',
        '9': 2,
        'a': 1,
        '5': 1,
      }, 5);
      expect(read, {1: 3, 5: 1});
      expect(match3ReadBestStars('nope', 5), isEmpty);
      expect(match3MergeBestStars({1: 1, 2: 3}, {1: 2, 3: 1}), {
        1: 2,
        2: 3,
        3: 1,
      });
    });

    testWidgets('grid shows locked, completed and stars from the save', (
      tester,
    ) async {
      bigView(tester);
      await seedSave({
        'schemaVersion': 3,
        'level': 1,
        'highestUnlockedLevel': 3,
        'bestStars': {'1': 3, '2': 1},
        'bestScore': 0,
        'board': flatBoard(),
        'score': 0,
        'moves': 20,
        'status': 'ready',
        'runActive': false,
        'rewarded': false,
        'runId': 1,
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      expect(grid.states, [
        LevelState.completed,
        LevelState.completed,
        LevelState.unlocked,
        LevelState.locked,
        LevelState.locked,
      ]);
      expect(grid.starsEarnedByLevel, {1: 3, 2: 1});
    });

    testWidgets('picking an unlocked level starts it and spends energy once', (
      tester,
    ) async {
      bigView(tester);
      await seedSave({
        'schemaVersion': 3,
        'level': 1,
        'highestUnlockedLevel': 3,
        'bestScore': 0,
        'board': flatBoard(),
        'score': 0,
        'moves': 20,
        'status': 'ready',
        'runActive': false,
        'rewarded': false,
        'runId': 1,
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final energy = Get.find<EnergyService>().currentEnergy;
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      grid.onLevelTap!(3);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Level 3/5'), findsOneWidget);
      expect(Get.find<EnergyService>().currentEnergy, energy - 1);
      expect(saved()['level'], 3);
    });

    testWidgets('a locked level cannot be started and costs nothing', (
      tester,
    ) async {
      bigView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final energy = Get.find<EnergyService>().currentEnergy;
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      grid.onLevelTap!(4);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Level 1/5'), findsOneWidget);
      expect(Get.find<EnergyService>().currentEnergy, energy);
    });

    testWidgets('level taps are ignored while a run is in progress', (
      tester,
    ) async {
      bigView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final start = find
          .ancestor(
            of: find.text('Start Run (-1 Energy)').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 200));
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      expect(grid.onLevelTap, isNull);
    });

    testWidgets('winning stores stars once and keeps the best', (tester) async {
      bigView(tester);
      final board = flatBoard();
      board[6] = 0;
      board[7] = 0;
      board[8] = 1;
      board[9] = 0;
      final game = Match3Engine(
        initialBoard: board,
        score: 1170,
        random: math.Random(22),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en'),
          fallbackLocale: AppTranslations.fallback,
          home: Match3LiteScreen(engine: game),
        ),
      );
      await tester.pump();
      final start = find
          .ancestor(
            of: find.text('Start Run (-1 Energy)').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(game.status, Match3Status.won);
      expect(game.moves, 19);
      // 19 of 20 moves left is >= 40%: three stars.
      expect(saved()['bestStars'], {'1': 3});
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      expect(grid.starsEarnedByLevel, {1: 3});
    });

    testWidgets('a worse later win never lowers the stored best stars', (
      tester,
    ) async {
      bigView(tester);
      await seedSave({
        'schemaVersion': 3,
        'level': 1,
        'highestUnlockedLevel': 1,
        'bestStars': {'1': 3},
        'bestScore': 0,
        'board': flatBoard(),
        'score': 0,
        'moves': 20,
        'status': 'ready',
        'runActive': false,
        'rewarded': false,
        'runId': 1,
      });
      final board = flatBoard();
      board[6] = 0;
      board[7] = 0;
      board[8] = 1;
      board[9] = 0;
      // 2 moves left of 20 is under 15%: this win alone is worth 1 star.
      final game = Match3Engine(
        initialBoard: board,
        score: 1170,
        moves: 2,
        status: Match3Status.playing,
        random: math.Random(22),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en'),
          fallbackLocale: AppTranslations.fallback,
          home: Match3LiteScreen(engine: game),
        ),
      );
      await tester.pump();
      final start = find
          .ancestor(
            of: find.text('Start Run (-1 Energy)').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(find.byKey(const ValueKey('match3_tile_8')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_8')));
      await tester.tap(find.byKey(const ValueKey('match3_tile_9')));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(game.status, Match3Status.won);
      expect(game.moves, 1);
      expect(saved()['bestStars'], {'1': 3});
    });

    testWidgets('a v2 save without stars migrates to v3 and loads', (
      tester,
    ) async {
      bigView(tester);
      await seedSave({
        'schemaVersion': 2,
        'level': 2,
        'highestUnlockedLevel': 2,
        'bestScore': 500,
        'board': flatBoard(),
        'score': 0,
        'moves': 20,
        'status': 'ready',
        'runActive': false,
        'rewarded': false,
        'runId': 1,
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Level 2/5'), findsOneWidget);
      expect(find.text('Best 500'), findsOneWidget);
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      expect(grid.starsEarnedByLevel, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cloud sync keeps the higher stars per level', (tester) async {
      bigView(tester);
      final localBoard = flatBoard();
      await seedSave({
        'schemaVersion': 3,
        'level': 1,
        'highestUnlockedLevel': 3,
        'bestStars': {'1': 1, '2': 3},
        'bestScore': 100,
        'board': localBoard,
        'score': 0,
        'moves': 20,
        'status': 'ready',
        'runActive': false,
        'rewarded': false,
        'runId': 1,
      });
      final cloud = _TestCloud()
        ..data = {
          'schemaVersion': 3,
          'syncedAtMs': 0,
          'level': 1,
          'highestUnlockedLevel': 2,
          'bestStars': {'1': 3, '3': 2},
          'bestScore': 900,
          'board': localBoard,
          'score': 0,
          'moves': 20,
          'status': 'ready',
          'runActive': false,
          'rewarded': false,
          'runId': 2,
        };
      await tester.pumpWidget(_wrap(cloud: cloud));
      await tester.pump();
      final syncButton = find
          .ancestor(
            of: find.text('Sync Save').first,
            matching: find.byType(CommonButton),
          )
          .first;
      await tester.ensureVisible(syncButton);
      await tester.tap(syncButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final grid = tester.widget<LevelSelectGrid>(find.byType(LevelSelectGrid));
      expect(grid.starsEarnedByLevel, {1: 3, 2: 3, 3: 2});
    });
  });
}
