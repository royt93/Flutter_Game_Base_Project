import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/challenge_card_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_screen_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';
import 'package:neon_jewels/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });

  tearDown(() => Get.reset());

  Widget appEn(Widget home) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    home: home,
  );

  // ─── startRush isolation ───────────────────────────────────────────────────

  group('Rush — startRush isolation', () {
    test('isRush bật, isSideMode = true', () {
      g.startRush();
      expect(g.isRush.value, isTrue);
      expect(g.isSideMode, isTrue);
    });

    test('startRush tắt mọi mode khác', () {
      g.startRush();
      expect(g.isEndless.value, isFalse);
      expect(g.isBoss.value, isFalse);
      expect(g.isZen.value, isFalse);
      expect(g.isSurvival.value, isFalse);
      expect(g.isLabyrinth.value, isFalse);
    });

    test('startRush set timeLeft = kRushInitialSeconds', () {
      g.startRush();
      expect(g.timeLeft.value, equals(GameController.kRushInitialSeconds));
    });

    test('startRush set moves = 999 (vô hạn)', () {
      g.startRush();
      expect(g.movesLeft.value, equals(999));
    });

    test('startRush KHÔNG trừ mạng (isSideMode)', () {
      final livesBefore = g.lives.value;
      g.startRush();
      // checkEnd với timeLeft > 0 → null
      expect(g.checkEnd(), isNull);
      expect(g.lives.value, equals(livesBefore));
    });
  });

  // ─── addScore → _rushTimeBonus ────────────────────────────────────────────

  group('Rush — time bonus khi match', () {
    setUp(() => g.startRush());

    test('match-3 (3 gems, combo=1) → +1s', () {
      final before = g.timeLeft.value;
      g.addScore(3, 1);
      expect(g.timeLeft.value, equals(before + 1));
    });

    test('match-4 (4 gems, combo=1) → +2s', () {
      final before = g.timeLeft.value;
      g.addScore(4, 1);
      expect(g.timeLeft.value, equals(before + 2));
    });

    test('match-5 (5 gems, combo=1) → +3s', () {
      final before = g.timeLeft.value;
      g.addScore(5, 1);
      expect(g.timeLeft.value, equals(before + 3));
    });

    test('cascade (combo=2) nhân đôi bonus', () {
      final before = g.timeLeft.value;
      g.addScore(3, 2); // base=1 → ×2 = 2s
      expect(g.timeLeft.value, equals(before + 2));
    });

    test('rushTimeBonus Rx cập nhật đúng', () {
      g.addScore(4, 1); // bonus = 2
      expect(g.rushTimeBonus.value, equals(2));
    });

    test('timeLeft không vượt kRushMaxSeconds', () {
      g.timeLeft.value = GameController.kRushMaxSeconds - 1;
      g.addScore(10, 3); // nhiều giây — phải clamp
      expect(g.timeLeft.value, equals(GameController.kRushMaxSeconds));
    });

    test('non-Rush mode: addScore KHÔNG cộng giờ', () {
      g.startEndless();
      final before = g.timeLeft.value;
      g.addScore(5, 1);
      expect(g.timeLeft.value, equals(before)); // timeLeft không đổi
    });
  });

  // ─── checkEnd ─────────────────────────────────────────────────────────────

  group('Rush — checkEnd', () {
    setUp(() => g.startRush());

    test('timeLeft > 0 → null (chơi tiếp)', () {
      expect(g.checkEnd(), isNull);
    });

    test('timeLeft = 0 → "lose"', () {
      g.timeLeft.value = 0;
      expect(g.checkEnd(), equals('lose'));
    });

    test('kết thúc KHÔNG đụng mạng (lose = side mode)', () {
      final livesBefore = g.lives.value;
      g.timeLeft.value = 0;
      g.checkEnd();
      expect(g.lives.value, equals(livesBefore));
    });

    test('kết thúc thưởng xu theo điểm (cap 80)', () {
      g.score.value = 50000;
      g.timeLeft.value = 0;
      final coinsBefore = g.coins.value;
      g.checkEnd();
      expect(g.coins.value, greaterThan(coinsBefore));
      expect(g.lastCoinReward, lessThanOrEqualTo(80));
    });
  });

  // ─── SideModeRecord ───────────────────────────────────────────────────────

  group('Rush — SideModeRecord', () {
    test('SideModeKind.rush có spec metric = bestScore', () {
      final spec = specForKind(SideModeKind.rush);
      expect(spec.metric, equals(RecordMetric.bestScore));
      expect(spec.key, equals('rush'));
    });

    test('activeKind trả rush khi isRush', () {
      g.startRush();
      final rec = Get.put(SideModeRecordController(g));
      expect(rec.activeKind, equals(SideModeKind.rush));
    });
  });

  group('Rush — integration regressions', () {
    test('GameScreenController.again restart Rush, không rơi về campaign', () {
      g.startRush();
      g.timeLeft.value = 0;
      g.score.value = 12345;
      final sc = GameScreenController(g);

      sc.again();

      expect(g.isRush.value, isTrue);
      expect(g.timeLeft.value, GameController.kRushInitialSeconds);
      expect(g.score.value, 0);
      expect(sc.ui.value, GameUi.playing);
    });

    test('Challenge Card có thể sinh và track Rush', () {
      expect(
        List.generate(80, buildWeeklyChallenges)
            .expand((cards) => cards)
            .where((card) => card.type == ChallengeType.playMode)
            .map((card) => card.modeKey),
        contains('rush_short'),
      );

      final cc = Get.put(ChallengeCardController(g));
      cc.challenges = const [
        ChallengeCard(
          type: ChallengeType.playMode,
          target: 2,
          reward: 100,
          modeKey: 'rush_short',
        ),
        ChallengeCard(type: ChallengeType.winCampaign, target: 3, reward: 100),
        ChallengeCard(type: ChallengeType.earnCoins, target: 300, reward: 100),
      ];
      cc.progress.assignAll([0, 0, 0]);
      cc.claimed.assignAll([false, false, false]);

      cc.onSideModePlayed('rush_short');

      expect(cc.progress[0], 1);
    });

    test(
      'engine Rush timer chỉ tick một lần dù current level là timeAttack',
      () {
        g.startRush();
        final game = NeonJewelGame(
          controller: g,
          rows: g.level.rows,
          cols: g.level.cols,
          colorCount: g.level.colorCount,
          onGameEnd: (_) {},
        );

        game.update(1.1);

        expect(g.timeLeft.value, GameController.kRushInitialSeconds - 1);
      },
    );

    testWidgets('GameScreen Rush HUD hiện timer, không hiện target giả', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      g.startRush();
      await tester.pumpWidget(appEn(const GameScreen()));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('999'), findsNothing);
      expect(find.textContaining('268'), findsNothing);
    });

    testWidgets('Rush result panel có chơi lại và restart Rush', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      g.startRush();
      g.score.value = 42000;
      g.timeLeft.value = 0;
      g.checkEnd();
      Get.put(SideModeRecordController(g));

      await tester.pumpWidget(appEn(const GameScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      final sc = Get.find<GameScreenController>();
      sc.ui.value = GameUi.lose;
      await tester.pump();

      expect(find.text('RUSH'), findsWidgets);
      expect(find.textContaining('42,000'), findsWidgets);
      await tester.tap(find.text('AGAIN'));
      await tester.pump(const Duration(milliseconds: 80));

      expect(g.isRush.value, isTrue);
      expect(g.timeLeft.value, GameController.kRushInitialSeconds);
      expect(sc.ui.value, GameUi.playing);
    });
  });
}
