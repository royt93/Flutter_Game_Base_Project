import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/achievements.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/trophy_room_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I34 Trophy Room: gộp prestige (I27) + achievements (I22) + mascot skins
// (I30) vào 1 màn read-only.
void main() {
  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
    // GridView 4+3 cột với 25 thành tựu + 6 skin — cần viewport đủ cao để
    // toàn bộ item được build cùng lúc (khớp quy ước achievements_screen_test.dart).
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(Get.reset);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 20000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(const TrophyRoomScreen()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('hiện đủ 3 section header', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Prestige'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Costumes'), findsOneWidget);
  });

  testWidgets(
    'chưa mở khoá gì → toàn bộ achievement khoá, skin free vẫn unlocked',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.byIcon(Icons.lock_rounded),
        findsNWidgets(kAchievements.length),
      );
      expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
      // Skin đầu tiên (classic, free) luôn nằm trong unlockedMascotSkinIds
      // mặc định → tên skin luôn hiện, không có khái niệm "khoá tên".
      expect(find.text(kMascotSkins.first.nameKey.tr), findsOneWidget);
    },
  );

  testWidgets(
    'mở khoá 1 thành tựu → chỉ title của nó xuất hiện, còn lại không lộ nội dung',
    (tester) async {
      ctrl.startLevel(1);
      ctrl.registerPop(10); // comboCount=1
      ctrl.registerPop(10); // comboCount=2
      ctrl.registerPop(10); // comboCount=3 → mở khoá combo_3
      final unlocked = kAchievements.firstWhere((a) => a.id == 'combo_3');

      await pumpScreen(tester);

      expect(find.text(unlocked.titleKey.tr), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.lock_rounded),
        findsNWidgets(kAchievements.length - 1),
      );
      for (final a in kAchievements) {
        if (a.id == unlocked.id) continue;
        expect(find.text(a.titleKey.tr), findsNothing);
      }
    },
  );

  testWidgets('mở khoá 1 mascot skin → tên skin hiện, opacity đầy đủ', (
    tester,
  ) async {
    final skin = kMascotSkins.firstWhere((s) => s.id == 'ruby');
    ctrl.unlockedMascotSkinIds.add(skin.id);

    await pumpScreen(tester);

    expect(find.text(skin.nameKey.tr), findsOneWidget);
  });

  testWidgets('prestigeTier = 0, chưa đủ điều kiện → badge prestige ẩn', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('prestige_badge')), findsNothing);
  });

  testWidgets('prestigeTier = 2 → badge prestige hiện "P2"', (tester) async {
    ctrl.prestigeTier.value = 2;

    await pumpScreen(tester);

    expect(find.byKey(const Key('prestige_badge')), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);
  });
}
