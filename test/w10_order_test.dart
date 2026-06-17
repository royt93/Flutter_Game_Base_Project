import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('Wave 10 — Order mode (mục tiêu hỗn hợp)', () {
    test('các màn kOrderLevels có objective order + 3 mục tiêu con', () {
      for (final idx in kOrderLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.order, reason: 'level $idx');
        expect(lv.orders.length, 3, reason: 'level $idx cần 3 màu');
        // 3 màu phải khác nhau (thử thách thật)
        final colors = lv.orders.map((o) => o.color).toSet();
        expect(colors.length, 3, reason: 'level $idx 3 màu phải khác nhau');
        for (final g in lv.orders) {
          expect(g.target, greaterThan(0));
        }
      }
    });

    test('không xô lệch rotation: order KHÔNG nằm trong kRotatingObjectives', () {
      expect(kRotatingObjectives, isNot(contains(ObjectiveType.order)));
    });

    test('startLevel khởi tạo orderProgress khớp số mục tiêu, toàn 0', () {
      final idx = kOrderLevels.first;
      c.startLevel(idx);
      expect(c.orderProgress.length, kLevels[idx - 1].orders.length);
      expect(c.orderProgress.every((v) => v == 0), isTrue);
      expect(c.hasWon, isFalse);
      expect(c.objectiveProgress, 0);
    });

    test('registerClear cộng đúng màu, clamp ở target; chưa đủ → chưa thắng', () {
      final idx = kOrderLevels.first;
      c.startLevel(idx);
      final lv = kLevels[idx - 1];
      final g0 = lv.orders[0];
      // clear dư số lượng màu thứ nhất → clamp ở target
      for (var i = 0; i < g0.target + 5; i++) {
        c.registerClear(g0.color, false);
      }
      expect(c.orderProgress[0], g0.target);
      expect(c.hasWon, isFalse); // còn 2 mục tiêu chưa đạt
      expect(c.objectiveProgress, greaterThan(0));
      expect(c.objectiveProgress, lessThan(1.0));
    });

    test('đủ cả 3 mục tiêu → hasWon = true, progress = 1.0', () {
      final idx = kOrderLevels.first;
      c.startLevel(idx);
      final lv = kLevels[idx - 1];
      for (final g in lv.orders) {
        for (var i = 0; i < g.target; i++) {
          c.registerClear(g.color, false);
        }
      }
      expect(c.orderProgress, lv.orders.map((g) => g.target).toList());
      expect(c.hasWon, isTrue);
      expect(c.objectiveProgress, 1.0);
    });

    test('checkEnd order: thắng đi qua nhánh thường → cộng win-streak', () {
      final idx = kOrderLevels.first;
      c.startLevel(idx);
      final lv = kLevels[idx - 1];
      for (final g in lv.orders) {
        for (var i = 0; i < g.target; i++) {
          c.registerClear(g.color, false);
        }
      }
      final r = c.checkEnd();
      expect(r, 'win');
      expect(c.winStreak.value, 1); // order là màn thường → tính chuỗi thắng
      expect(c.lastStars, greaterThanOrEqualTo(1));
    });

    test('chuyển sang mode khác reset orderProgress về rỗng', () {
      c.startLevel(kOrderLevels.first);
      expect(c.orderProgress, isNotEmpty);
      c.startEndless();
      expect(c.orderProgress, isEmpty); // endless không có order
    });
  });
}
