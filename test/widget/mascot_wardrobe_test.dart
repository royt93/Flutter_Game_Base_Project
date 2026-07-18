import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/mascot_wardrobe_screen.dart';
import 'package:pop_star_blast/presentation/widgets/star_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I30 Mascot Wardrobe: widget test còn thiếu theo acceptance criteria —
// "mascot vẽ đúng palette khi đổi skin active".
void main() {
  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  // Cùng pattern Obx(() => StarMascot(palette: gameCtrl.activeMascotSkin.palette))
  // đang dùng thật ở home_screen.dart/game_screen.dart — xác nhận đúng
  // acceptance criteria: đổi skin active thì mascot vẽ lại đúng palette mới.
  Widget activeSkinMascotHarness() =>
      Obx(() => StarMascot(palette: ctrl.activeMascotSkin.palette));

  testWidgets('mascot dùng palette classic khi chưa mua/chọn skin nào khác', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(activeSkinMascotHarness()));
    await tester.pump();

    final mascot = tester.widget<StarMascot>(find.byType(StarMascot));
    final classic = kMascotSkins.firstWhere((s) => s.id == 'classic');
    expect(mascot.palette, classic.palette);
  });

  testWidgets(
    'chọn active skin khác → mascot vẽ lại với đúng palette mới (Obx phản '
    'ứng theo Rx activeMascotSkinId)',
    (tester) async {
      await tester.pumpWidget(_wrap(activeSkinMascotHarness()));
      await tester.pump();

      ctrl.coins.value = 300;
      final ruby = kMascotSkins.firstWhere((s) => s.id == 'ruby');
      expect(ctrl.buySkin(ruby), isTrue);
      expect(ctrl.selectMascotSkin('ruby'), isTrue);
      await tester.pump();

      final mascot = tester.widget<StarMascot>(find.byType(StarMascot));
      expect(mascot.palette, ruby.palette);
      expect(mascot.palette, isNot(kMascotSkins.first.palette));
    },
  );

  testWidgets(
    'mở khoá skin qua achievement (combo_25) rồi chọn active → mascot vẽ '
    'đúng palette aurora',
    (tester) async {
      await tester.pumpWidget(_wrap(activeSkinMascotHarness()));
      await tester.pump();

      ctrl.startLevel(1);
      for (var i = 0; i < 25; i++) {
        ctrl.registerPop(10);
      }
      expect(ctrl.unlockedMascotSkinIds, contains('aurora'));

      expect(ctrl.selectMascotSkin('aurora'), isTrue);
      await tester.pump();

      final mascot = tester.widget<StarMascot>(find.byType(StarMascot));
      final aurora = kMascotSkins.firstWhere((s) => s.id == 'aurora');
      expect(mascot.palette, aurora.palette);
    },
  );

  group('MascotWardrobeScreen', () {
    // GridView chỉ build item trong viewport — cần viewport đủ cao để cả 6
    // skin được build cùng lúc (khớp quy ước achievements_screen_test.dart).
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('render lưới đủ số skin, mỗi thẻ vẽ đúng palette của skin đó', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(const MascotWardrobeScreen()));
      await tester.pump();

      final mascots = tester
          .widgetList<StarMascot>(find.byType(StarMascot))
          .toList();
      expect(mascots.length, kMascotSkins.length);
      for (var i = 0; i < kMascotSkins.length; i++) {
        expect(mascots[i].palette, kMascotSkins[i].palette);
      }
    });

    testWidgets(
      'mua skin đủ xu → thẻ chuyển sang trạng thái "Select"; tap Select → '
      'skin trở thành active, thẻ hiện nhãn "Selected"',
      (tester) async {
        useTallSurface(tester);
        // 350 (khác giá mọi skin: 300/600/1000) để text giá "300" của thẻ
        // ruby không lẫn với số dư xu hiển thị ở CoinChip.
        ctrl.coins.value = 350;
        await tester.pumpWidget(_wrap(const MascotWardrobeScreen()));
        await tester.pump();

        // Nút mua chỉ hiện icon xu + giá số (không có text "Buy") — tap
        // đúng vào text giá của ruby (300).
        await tester.tap(find.text('300').first);
        await tester.pump();
        expect(ctrl.unlockedMascotSkinIds, contains('ruby'));

        await tester.tap(find.text('Select').first);
        await tester.pump();

        expect(ctrl.activeMascotSkinId.value, 'ruby');
        expect(find.text('Selected'), findsOneWidget);
      },
    );

    testWidgets('thiếu xu → nút mua bị disable, tap không mở khoá skin', (
      tester,
    ) async {
      useTallSurface(tester);
      ctrl.coins.value = 0;
      await tester.pumpWidget(_wrap(const MascotWardrobeScreen()));
      await tester.pump();

      // canAfford=false → onTap: null, tap vào text giá không làm gì.
      await tester.tap(find.text('300').first);
      await tester.pump();

      expect(ctrl.unlockedMascotSkinIds, isNot(contains('ruby')));
    });
  });
}
