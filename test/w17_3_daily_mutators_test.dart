import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W17.3 — Daily Mutator.
/// Test: tính chất tất định, áp config đúng, công thức doubleCombo, isolation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── dailyMutatorsFor — tính chất cơ bản ────────────────────────────────

  group('dailyMutatorsFor — tính chất cơ bản', () {
    test('cùng epochDay → cùng mutators (tất định)', () {
      expect(dailyMutatorsFor(1000), equals(dailyMutatorsFor(1000)));
      expect(dailyMutatorsFor(2025), equals(dailyMutatorsFor(2025)));
      expect(dailyMutatorsFor(0), equals(dailyMutatorsFor(0)));
    });

    test('20 ngày liên tiếp không đồng nhất (có ≥2 kết quả khác nhau)', () {
      final results = List.generate(20, dailyMutatorsFor);
      // Không thể tất cả 20 ngày đều cho cùng 1 mutator
      expect(results.map((r) => r.toString()).toSet().length, greaterThan(1));
    });

    test('luôn trả 1-2 mutator', () {
      for (var d = 0; d < 100; d++) {
        final m = dailyMutatorsFor(d);
        expect(m.length, inInclusiveRange(1, 2),
            reason: 'ngày $d: ${m.length} mutator (ngoài phạm vi 1-2)');
      }
    });

    test('khi có 2 mutator, hai cái phải khác nhau', () {
      for (var d = 0; d < 200; d++) {
        final m = dailyMutatorsFor(d);
        if (m.length == 2) {
          expect(m[0], isNot(equals(m[1])),
              reason: 'ngày $d: 2 mutator trùng (${m[0]})');
        }
      }
    });

    test('mọi mutator đều xuất hiện ít nhất 1 lần trong 500 ngày', () {
      final appeared = <DailyMutator>{};
      for (var d = 0; d < 500; d++) {
        appeared.addAll(dailyMutatorsFor(d));
      }
      for (final m in DailyMutator.values) {
        expect(appeared.contains(m), isTrue,
            reason: 'Mutator $m chưa xuất hiện sau 500 ngày');
      }
    });
  });

  // ─── buildDailyLevel với mutators — áp config ────────────────────────────

  group('buildDailyLevel với mutators — cấu hình', () {
    test('rỗng mutators → config giống base', () {
      final base = buildDailyLevel(1000);
      final withEmpty = buildDailyLevel(1000, mutators: const []);
      expect(withEmpty.colorCount, base.colorCount);
      expect(withEmpty.moves, base.moves);
      expect(withEmpty.noSpecial, isFalse);
      expect(withEmpty.doubleCombo, isFalse);
    });

    test('only4Colors → colorCount = 4', () {
      for (var d = 0; d < 5; d++) {
        final cfg = buildDailyLevel(d, mutators: const [DailyMutator.only4Colors]);
        expect(cfg.colorCount, 4, reason: 'ngày $d');
      }
    });

    test('only4Colors + collect: collectColor.index < 4 (ngày ≡ 1 mod 5)', () {
      // kDailyObjectives[1] = collect → ngày ≡ 1 mod 5
      const collectDay = 1;
      final cfg = buildDailyLevel(collectDay,
          mutators: const [DailyMutator.only4Colors]);
      expect(cfg.objective, ObjectiveType.collect);
      // Kể cả khi base-color là index 4 hoặc 5, re-pick phải đưa về [0, 3].
      expect(cfg.collectColor!.index, lessThan(4));
    });

    test('lowMoves → moves giảm 7, sàn 16', () {
      for (var d = 0; d < 10; d++) {
        final base = buildDailyLevel(d);
        final cfg = buildDailyLevel(d, mutators: const [DailyMutator.lowMoves]);
        expect(cfg.moves, (base.moves - 7).clamp(16, 9999),
            reason: 'ngày $d');
        expect(cfg.moves, greaterThanOrEqualTo(16));
      }
    });

    test('bonusMoves → moves tăng 8', () {
      for (var d = 0; d < 5; d++) {
        final base = buildDailyLevel(d);
        final cfg = buildDailyLevel(d, mutators: const [DailyMutator.bonusMoves]);
        expect(cfg.moves, base.moves + 8, reason: 'ngày $d');
      }
    });

    test('doubleCombo → cờ bật, colorCount/moves giữ nguyên', () {
      final base = buildDailyLevel(1000);
      final cfg =
          buildDailyLevel(1000, mutators: const [DailyMutator.doubleCombo]);
      expect(cfg.doubleCombo, isTrue);
      expect(cfg.colorCount, base.colorCount);
      expect(cfg.moves, base.moves);
    });

    test('noSpecial → cờ bật, colorCount/moves giữ nguyên', () {
      final base = buildDailyLevel(1000);
      final cfg =
          buildDailyLevel(1000, mutators: const [DailyMutator.noSpecial]);
      expect(cfg.noSpecial, isTrue);
      expect(cfg.colorCount, base.colorCount);
      expect(cfg.moves, base.moves);
    });

    test('kết hợp lowMoves + doubleCombo → cả 2 áp đồng thời', () {
      final base = buildDailyLevel(1000);
      final cfg = buildDailyLevel(1000, mutators: const [
        DailyMutator.lowMoves,
        DailyMutator.doubleCombo,
      ]);
      expect(cfg.moves, (base.moves - 7).clamp(16, 9999));
      expect(cfg.doubleCombo, isTrue);
      expect(cfg.noSpecial, isFalse);
    });

    test('kết hợp only4Colors + noSpecial', () {
      final cfg = buildDailyLevel(1000, mutators: const [
        DailyMutator.only4Colors,
        DailyMutator.noSpecial,
      ]);
      expect(cfg.colorCount, 4);
      expect(cfg.noSpecial, isTrue);
    });

    test('index giữ nguyên kDailyLevelIndex', () {
      for (final m in DailyMutator.values) {
        final cfg = buildDailyLevel(1000, mutators: [m]);
        expect(cfg.index, kDailyLevelIndex, reason: 'mutator $m');
      }
    });

    test('rows/cols luôn 8×8', () {
      for (final m in DailyMutator.values) {
        final cfg = buildDailyLevel(1000, mutators: [m]);
        expect(cfg.rows, 8);
        expect(cfg.cols, 8);
      }
    });

    test('LevelConfig mặc định không có mutator (noSpecial=false, doubleCombo=false)', () {
      const cfg = LevelConfig(
          index: 1, rows: 8, cols: 8, colorCount: 6, moves: 30);
      expect(cfg.noSpecial, isFalse);
      expect(cfg.doubleCombo, isFalse);
    });
  });

  // ─── doubleCombo — công thức scoring (pure math) ─────────────────────────

  group('doubleCombo — công thức scoring thuần', () {
    // Công thức hiện tại:
    //   comboBonusMult = doubleCombo ? 1.0 : 0.5
    //   multiplier = 1 + (combo - 1) * comboBonusMult
    //   gained = (gemsCleared * 10 * multiplier).round()

    double calcGained(int gems, int combo, {bool doubleCombo = false}) {
      final mult = doubleCombo ? 1.0 : 0.5;
      final multiplier = 1 + (combo - 1) * mult;
      return (gems * 10 * multiplier).roundToDouble();
    }

    test('combo=1 → multiplier=1 bất kể doubleCombo', () {
      expect(calcGained(5, 1), calcGained(5, 1, doubleCombo: true));
    });

    test('combo=2: normal×1.5 vs double×2.0', () {
      expect(calcGained(5, 2), 75);
      expect(calcGained(5, 2, doubleCombo: true), 100);
    });

    test('combo=3: normal×2.0 vs double×3.0', () {
      expect(calcGained(10, 3), 200);
      expect(calcGained(10, 3, doubleCombo: true), 300);
    });

    test('combo=4: normal×2.5 vs double×4.0', () {
      expect(calcGained(5, 4), (5 * 10 * 2.5).roundToDouble());
      expect(calcGained(5, 4, doubleCombo: true), (5 * 10 * 4.0).roundToDouble());
    });

    test('doubleCombo luôn cho điểm cao hơn khi combo ≥ 2', () {
      for (var combo = 2; combo <= 8; combo++) {
        expect(calcGained(10, combo, doubleCombo: true),
            greaterThan(calcGained(10, combo)),
            reason: 'combo=$combo');
      }
    });
  });

  // ─── GameController — todayMutators getter ───────────────────────────────

  group('GameController — todayMutators getter', () {
    late GameController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });

    tearDown(() => Get.reset());

    test('todayMutators không rỗng', () {
      expect(c.todayMutators, isNotEmpty);
    });

    test('todayMutators = dailyMutatorsFor(todayEpochDay) (tất định)', () {
      expect(c.todayMutators, dailyMutatorsFor(c.todayEpochDay));
    });

    test('todayMutators gọi 2 lần cùng kết quả', () {
      expect(c.todayMutators, c.todayMutators);
    });
  });

  // ─── startDaily() → level config chứa mutators đúng ─────────────────────

  group('startDaily() — integration: level.noSpecial / level.doubleCombo', () {
    late GameController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });

    tearDown(() => Get.reset());

    test('startDaily() → isDaily = true', () {
      c.startDaily();
      expect(c.isDaily.value, isTrue);
    });

    test('startDaily() → level.noSpecial khớp với mutator thực tế', () {
      c.startDaily();
      final mutators = dailyMutatorsFor(c.todayEpochDay);
      final expected = mutators.contains(DailyMutator.noSpecial);
      expect(c.level.noSpecial, expected,
          reason: 'mutators=$mutators → noSpecial=$expected');
    });

    test('startDaily() → level.doubleCombo khớp với mutator thực tế', () {
      c.startDaily();
      final mutators = dailyMutatorsFor(c.todayEpochDay);
      final expected = mutators.contains(DailyMutator.doubleCombo);
      expect(c.level.doubleCombo, expected,
          reason: 'mutators=$mutators → doubleCombo=$expected');
    });

    test('startDaily() → level.colorCount = 4 nếu only4Colors active', () {
      c.startDaily();
      final mutators = dailyMutatorsFor(c.todayEpochDay);
      if (mutators.contains(DailyMutator.only4Colors)) {
        expect(c.level.colorCount, 4);
      } else {
        expect(c.level.colorCount, 6);
      }
    });

    test('buildDailyLevel bắc cầu: level bằng với mutators áp thủ công', () {
      // Đảm bảo startDaily và buildDailyLevel(day, mutators) cho cùng kết quả.
      c.startDaily();
      final day = c.todayEpochDay;
      final mutators = dailyMutatorsFor(day);
      final expected = buildDailyLevel(day, mutators: mutators);
      expect(c.level.noSpecial, expected.noSpecial);
      expect(c.level.doubleCombo, expected.doubleCombo);
      expect(c.level.colorCount, expected.colorCount);
      expect(c.level.moves, expected.moves);
    });
  });

  // ─── dailyMutatorsFor — không có cặp triệt tiêu nhau ────────────────────

  group('dailyMutatorsFor — không cặp triệt tiêu', () {
    test('lowMoves + bonusMoves không bao giờ xuất hiện cùng nhau', () {
      for (var d = 0; d < 1000; d++) {
        final m = dailyMutatorsFor(d);
        final hasLow = m.contains(DailyMutator.lowMoves);
        final hasBonus = m.contains(DailyMutator.bonusMoves);
        expect(hasLow && hasBonus, isFalse,
            reason: 'ngày $d: lowMoves + bonusMoves cùng xuất hiện');
      }
    });
  });

  // ─── only4Colors — phân phối collectColor không lệch ────────────────────

  group('only4Colors — collectColor luôn trong [0, 3]', () {
    test('collect ngày + only4Colors: collectColor.index < 4 với mọi ngày', () {
      // Kiểm tra mọi ngày có objective = collect (mod 5 = 1)
      var tested = 0;
      for (var d = 1; d < 100; d += 5) {
        // d%5=1 → objective=collect
        final cfg = buildDailyLevel(d,
            mutators: const [DailyMutator.only4Colors]);
        expect(cfg.objective, ObjectiveType.collect, reason: 'ngày $d');
        if (cfg.collectColor != null) {
          expect(cfg.collectColor!.index, lessThan(4),
              reason: 'ngày $d: index=${cfg.collectColor!.index}');
          tested++;
        }
      }
      expect(tested, greaterThan(0),
          reason: 'Không ngày nào kiểm tra được collectColor');
    });

    test('collectColor re-pick tất định (cùng ngày cùng màu)', () {
      const day = 6; // ngày collect với index 4 or 5 có thể xảy ra
      final cfg1 = buildDailyLevel(day,
          mutators: const [DailyMutator.only4Colors]);
      final cfg2 = buildDailyLevel(day,
          mutators: const [DailyMutator.only4Colors]);
      expect(cfg1.collectColor, cfg2.collectColor);
    });
  });

  // ─── DailyMutatorName extension ──────────────────────────────────────────

  group('DailyMutatorName.keyName', () {
    test('mỗi mutator có keyName unique, không rỗng, không khoảng trắng', () {
      final names = DailyMutator.values.map((m) => m.keyName).toList();
      expect(names.toSet().length, names.length,
          reason: 'keyName phải unique');
      for (final (i, name) in names.indexed) {
        expect(name, isNotEmpty, reason: 'mutator[$i] keyName rỗng');
        expect(name, isNot(contains(' ')),
            reason: 'keyName không được chứa khoảng trắng');
      }
    });

    test('prefix i18n hợp lệ: daily_mut_<keyName>', () {
      // Tất cả key đều bắt đầu bằng chữ thường/số (hợp lệ cho i18n)
      for (final m in DailyMutator.values) {
        expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(m.keyName), isTrue,
            reason: '${m.keyName} có ký tự không hợp lệ');
      }
    });
  });
}
