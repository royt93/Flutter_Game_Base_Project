import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/perks.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/perks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `PerksScreen` (F14) — chưa có test nào.
///
/// Đáng test vì nó là **giao diện duy nhất** cho luật "tối đa 2 perk cùng
/// lúc". Luật đó nằm ở `GameController.togglePerkSelection` (thuần, đã có
/// test), nhưng màn hình mới là chỗ quyết định perk nào **bấm được**: perk
/// chưa mở khoá phải trơ, nếu không người chơi bật được thứ chưa kiếm ra.
late GameController gameCtrl;

Future<void> _pump(WidgetTester tester, {int unlockedLevel = 1}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.unlockedLevel: unlockedLevel,
  });
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const PerksScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapPerk(WidgetTester tester, Perk perk) async {
  final row = find.text(perk.nameKey.tr);
  await tester.ensureVisible(row.first);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(row.first);
  await tester.pump(const Duration(milliseconds: 250));
}

/// Level đủ cao để mọi perk đều mở khoá.
int get _allUnlockedLevel => 260;

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(PerksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liệt kê đủ mọi perk, kể cả chưa mở khoá', (tester) async {
      await _pump(tester);
      for (final p in kPerks) {
        expect(
          find.text(p.nameKey.tr),
          findsWidgets,
          reason:
              'perk "${p.id}" phải hiện để người chơi biết có gì phía trước',
        );
      }
    });
  });

  group('perk chưa mở khoá', () {
    testWidgets('bấm không bật được', (tester) async {
      await _pump(tester, unlockedLevel: 1);
      final locked = kPerks.firstWhere(
        (p) => !gameCtrl.unlockedPerksList.any((u) => u.id == p.id),
      );

      await _tapPerk(tester, locked);

      expect(
        gameCtrl.activePerkIds,
        isNot(contains(locked.id)),
        reason: 'bật được perk chưa kiếm ra là cho không sức mạnh',
      );
    });

    testWidgets('hasPerk vẫn false dù id lọt vào danh sách active', (
      tester,
    ) async {
      // Tuyến phòng thủ thứ hai: kể cả storage bị sửa tay để nhét id vào
      // activePerks, `hasPerk` vẫn kiểm lại theo perk đã mở khoá.
      await _pump(tester, unlockedLevel: 1);
      final locked = kPerks.firstWhere(
        (p) => !gameCtrl.unlockedPerksList.any((u) => u.id == p.id),
      );
      gameCtrl.activePerkIds.value = [locked.id];

      expect(gameCtrl.hasPerk(locked.id), isFalse);
    });
  });

  group('perk đã mở khoá', () {
    testWidgets('bấm để bật, bấm lại để tắt', (tester) async {
      await _pump(tester, unlockedLevel: _allUnlockedLevel);
      final perk = kPerks.first;

      await _tapPerk(tester, perk);
      expect(gameCtrl.activePerkIds, contains(perk.id));
      expect(gameCtrl.hasPerk(perk.id), isTrue);

      await _tapPerk(tester, perk);
      expect(gameCtrl.activePerkIds, isNot(contains(perk.id)));
    });

    testWidgets('lựa chọn được persist', (tester) async {
      await _pump(tester, unlockedLevel: _allUnlockedLevel);
      await _tapPerk(tester, kPerks.first);

      expect(
        StorageService.to.getString(StorageKeys.activePerks),
        contains(kPerks.first.id),
      );
    });
  });

  group('trần 2 perk cùng lúc', () {
    testWidgets('bật perk thứ 3 không ăn, 2 perk cũ giữ nguyên', (
      tester,
    ) async {
      await _pump(tester, unlockedLevel: _allUnlockedLevel);
      expect(
        kPerks.length,
        greaterThanOrEqualTo(3),
        reason: 'cần ít nhất 3 perk mới kiểm được trần 2',
      );

      await _tapPerk(tester, kPerks[0]);
      await _tapPerk(tester, kPerks[1]);
      expect(gameCtrl.activePerkIds.length, 2);

      await _tapPerk(tester, kPerks[2]);

      expect(gameCtrl.activePerkIds.length, 2);
      expect(gameCtrl.activePerkIds, contains(kPerks[0].id));
      expect(gameCtrl.activePerkIds, contains(kPerks[1].id));
      expect(
        gameCtrl.activePerkIds,
        isNot(contains(kPerks[2].id)),
        reason: 'trần phải chặn, không được lặng lẽ đẩy perk cũ ra',
      );
    });

    testWidgets('tắt bớt 1 rồi mới bật được perk khác', (tester) async {
      await _pump(tester, unlockedLevel: _allUnlockedLevel);
      await _tapPerk(tester, kPerks[0]);
      await _tapPerk(tester, kPerks[1]);

      await _tapPerk(tester, kPerks[0]); // tắt
      await _tapPerk(tester, kPerks[2]); // giờ mới còn chỗ

      expect(gameCtrl.activePerkIds, contains(kPerks[2].id));
      expect(gameCtrl.activePerkIds.length, 2);
    });
  });
}
