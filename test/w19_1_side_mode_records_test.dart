import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';
import 'package:neon_jewels/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W19.1 — Kỷ lục & cột mốc chế độ phụ.
/// Test: spec thuần, recordResult (best/winCount/milestone/anti-double),
/// resetState, registration + badge qua HomeScreen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ─── 1) Spec thuần (không cần GetX) ──────────────────────────────────────

  group('SideModeRecordSpec — thuần', () {
    test('mỗi SideModeKind có đúng 1 spec', () {
      for (final k in SideModeKind.values) {
        final matches = kSideModeRecords.where((s) => s.kind == k).toList();
        expect(matches.length, 1, reason: 'kind $k phải có đúng 1 spec');
      }
    });

    test('key là duy nhất', () {
      final keys = kSideModeRecords.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('ngưỡng tăng dần bronze < silver < gold', () {
      for (final s in kSideModeRecords) {
        expect(s.bronze, lessThan(s.silver), reason: '${s.key} bronze<silver');
        expect(s.silver, lessThan(s.gold), reason: '${s.key} silver<gold');
      }
    });

    test('tierFor trả đúng bậc theo giá trị', () {
      final s = specForKind(SideModeKind.endless); // 5/15/30
      expect(s.tierFor(0), RecordTier.none);
      expect(s.tierFor(4), RecordTier.none);
      expect(s.tierFor(5), RecordTier.bronze);
      expect(s.tierFor(14), RecordTier.bronze);
      expect(s.tierFor(15), RecordTier.silver);
      expect(s.tierFor(29), RecordTier.silver);
      expect(s.tierFor(30), RecordTier.gold);
      expect(s.tierFor(999), RecordTier.gold);
    });

    test('thresholdFor khớp ngưỡng', () {
      final s = specForKind(SideModeKind.boss); // 1/3/5
      expect(s.thresholdFor(RecordTier.none), 0);
      expect(s.thresholdFor(RecordTier.bronze), 1);
      expect(s.thresholdFor(RecordTier.silver), 3);
      expect(s.thresholdFor(RecordTier.gold), 5);
    });

    test('RecordTier.index dùng để so sánh tiến triển', () {
      expect(RecordTier.none.index, 0);
      expect(RecordTier.bronze.index, 1);
      expect(RecordTier.silver.index, 2);
      expect(RecordTier.gold.index, 3);
    });

    test('endless/boss = bestStage, survival = bestScore, còn lại winCount', () {
      expect(specForKind(SideModeKind.endless).metric, RecordMetric.bestStage);
      expect(specForKind(SideModeKind.boss).metric, RecordMetric.bestStage);
      expect(specForKind(SideModeKind.survival).metric, RecordMetric.bestScore);
      for (final k in [
        SideModeKind.rhythm,
        SideModeKind.gravity,
        SideModeKind.colorRush,
        SideModeKind.soda,
        SideModeKind.labyrinth,
      ]) {
        expect(specForKind(k).metric, RecordMetric.winCount, reason: '$k');
      }
    });
  });

  // ─── 2) Controller — recordResult ────────────────────────────────────────

  group('SideModeRecordController — recordResult', () {
    late GameController g;
    late SideModeRecordController rec;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      rec = Get.put(SideModeRecordController(g));
    });
    tearDown(Get.reset);

    test('endless bestStage: phá kỷ lục + mở mốc bronze', () {
      g.startEndless();
      g.endlessStage.value = 7;
      final o = rec.recordResult(won: false)!;
      expect(o.kind, SideModeKind.endless);
      expect(o.newValue, 7);
      expect(o.newBest, isTrue);
      expect(o.newTier, RecordTier.bronze);
      expect(o.milestoneCoins, kTierReward[RecordTier.bronze]);
      expect(rec.recordOf(SideModeKind.endless), 7);
      expect(rec.tierOf(SideModeKind.endless), RecordTier.bronze);
    });

    test('endless: stage thấp hơn KHÔNG hạ kỷ lục', () {
      g.startEndless();
      g.endlessStage.value = 20;
      rec.recordResult(won: false); // record=20, silver
      g.startEndless();
      g.endlessStage.value = 3;
      final o = rec.recordResult(won: false)!;
      expect(o.newBest, isFalse);
      expect(rec.recordOf(SideModeKind.endless), 20);
      expect(rec.tierOf(SideModeKind.endless), RecordTier.silver);
    });

    test('endless: vượt nhiều bậc 1 lần → cộng dồn xu các bậc mới', () {
      g.startEndless();
      g.endlessStage.value = 30; // gold ngay từ đầu (qua bronze+silver+gold)
      final coinsBefore = g.coins.value;
      final o = rec.recordResult(won: false)!;
      expect(o.newTier, RecordTier.gold);
      final expected = kTierReward[RecordTier.bronze]! +
          kTierReward[RecordTier.silver]! +
          kTierReward[RecordTier.gold]!;
      expect(o.milestoneCoins, expected);
      expect(g.coins.value - coinsBefore, expected);
    });

    test('boss bestStage: chỉ tính khi THẮNG', () {
      g.startBoss(4);
      // thua → run=0 → không ghi
      final lose = rec.recordResult(won: false)!;
      expect(lose.newValue, 0);
      expect(lose.newTier, RecordTier.none);
      // thắng stage 4 → record=4, silver
      final win = rec.recordResult(won: true)!;
      expect(win.newValue, 4);
      expect(win.newBest, isTrue);
      expect(win.newTier, RecordTier.silver); // 4 >= 3
    });

    test('survival bestScore', () {
      g.startSurvival();
      g.score.value = 5500;
      final o = rec.recordResult(won: false)!;
      expect(o.newValue, 5500);
      expect(o.newTier, RecordTier.silver); // 5500 >= 5000
    });

    test('winCount (rhythm): chỉ tăng khi thắng, mốc theo số lần thắng', () {
      g.startRhythm();
      // thua → không tăng
      final lose = rec.recordResult(won: false)!;
      expect(lose.newValue, 0);
      expect(lose.newBest, isFalse);
      // thắng lần 1 → count=1 → bronze
      final w1 = rec.recordResult(won: true)!;
      expect(w1.newValue, 1);
      expect(w1.newBest, isFalse); // bộ đếm, không phải "best"
      expect(w1.newTier, RecordTier.bronze);
      // thắng thêm 4 lần → count=5 → silver
      for (var i = 0; i < 3; i++) {
        rec.recordResult(won: true);
      }
      final w5 = rec.recordResult(won: true)!;
      expect(w5.newValue, 5);
      expect(w5.newTier, RecordTier.silver);
    });

    test('anti-double: mốc đã nhận KHÔNG thưởng lại', () {
      g.startEndless();
      g.endlessStage.value = 7; // bronze
      rec.recordResult(won: false);
      final coinsAfterFirst = g.coins.value;
      // chơi lại cùng stage → không mốc mới
      g.startEndless();
      g.endlessStage.value = 7;
      final o = rec.recordResult(won: false)!;
      expect(o.newTier, RecordTier.none);
      expect(o.milestoneCoins, 0);
      expect(g.coins.value, coinsAfterFirst);
    });

    test('playsOf tăng mỗi ván (kể cả thua)', () {
      g.startEndless();
      expect(rec.playsOf(SideModeKind.endless), 0);
      rec.recordResult(won: false);
      rec.recordResult(won: false);
      expect(rec.playsOf(SideModeKind.endless), 2);
    });

    test('daily/versus → recordResult trả null (không track)', () {
      g.startDaily();
      expect(rec.recordResult(won: true), isNull);
    });

    test('persist: ghi đĩa → controller mới đọc lại đúng', () async {
      g.startEndless();
      g.endlessStage.value = 16; // silver
      rec.recordResult(won: false);
      // controller mới đọc lại từ đĩa
      final rec2 = SideModeRecordController(g);
      rec2.onInit();
      expect(rec2.recordOf(SideModeKind.endless), 16);
      expect(rec2.tierOf(SideModeKind.endless), RecordTier.silver);
    });

    test('persist + reload: milestone đã nhận KHÔNG bị claim lại sau restart', () async {
      // Đạt gold (stage 30) → milestone bronze/silver/gold đều nhận
      g.startEndless();
      g.endlessStage.value = 30; // gold threshold
      final coins0 = g.coins.value;
      rec.recordResult(won: false);
      final coinsAfterFirst = g.coins.value;
      expect(coinsAfterFirst, greaterThan(coins0), reason: 'nhận xu milestone');

      // Reload controller từ đĩa (simulate app restart)
      final rec2 = SideModeRecordController(g);
      rec2.onInit();
      // Nhập lại result cùng stage → milestones đã claimed, không thưởng lại
      final coinsBefore = g.coins.value;
      g.startEndless();
      g.endlessStage.value = 30;
      rec2.recordResult(won: false);
      expect(g.coins.value, coinsBefore, reason: 'anti-double: không thưởng milestone đã nhận');
    });

    test('resetState xoá hết kỷ lục in-memory', () {
      g.startEndless();
      g.endlessStage.value = 30;
      rec.recordResult(won: false);
      expect(rec.recordOf(SideModeKind.endless), 30);
      rec.resetState();
      expect(rec.recordOf(SideModeKind.endless), 0);
      expect(rec.tierOf(SideModeKind.endless), RecordTier.none);
      expect(rec.playsOf(SideModeKind.endless), 0);
    });
  });

  // ─── 3) resetProgress xoá kỷ lục trên đĩa ────────────────────────────────

  group('resetProgress — xoá kỷ lục', () {
    test('reset xoá rec_* trên đĩa + RAM', () async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final g = Get.put(GameController());
      final rec = Get.put(SideModeRecordController(g));
      g.startEndless();
      g.endlessStage.value = 30;
      rec.recordResult(won: false);
      expect(rec.tierOf(SideModeKind.endless), RecordTier.gold);

      await g.resetProgress();
      // RAM clear (resetState gọi qua maybe)
      expect(rec.recordOf(SideModeKind.endless), 0);
      // đĩa clear: controller mới đọc lại = 0
      final rec2 = SideModeRecordController(g);
      rec2.onInit();
      expect(rec2.recordOf(SideModeKind.endless), 0);
      expect(rec2.tierOf(SideModeKind.endless), RecordTier.none);
      Get.reset();
    });
  });

  // ─── 4) Widget — badge huy chương trên HomeScreen ────────────────────────

  group('HomeScreen — badge kỷ lục', () {
    Widget appEn(Widget home) => GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: AppTranslations.fallback,
          home: home,
        );

    testWidgets('mode đã đạt gold → hiện huy chương; controller load đúng',
        (tester) async {
      // Seed sẵn endless = gold trên đĩa.
      SharedPreferences.setMockInitialValues({
        'rec_endless_v': 30,
        'rec_endless_t': 3,
      });
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Controller được đăng ký + load đúng tier qua HomeScreen.build.
      final rec = Get.find<SideModeRecordController>();
      expect(rec.tierOf(SideModeKind.endless), RecordTier.gold);
      // Huy chương (emoji_events) xuất hiện ít nhất 1 lần.
      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
      Get.reset();
    });

    testWidgets('chưa đạt mốc nào → controller tier = none', (tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final rec = Get.find<SideModeRecordController>();
      for (final k in SideModeKind.values) {
        expect(rec.tierOf(k), RecordTier.none, reason: '$k chưa đạt mốc');
      }
      Get.reset();
    });
  });
}
