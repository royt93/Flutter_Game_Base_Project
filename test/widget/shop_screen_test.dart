import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GameController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: AppTranslations.fallback,
        home: home,
      );

  final paidSkin = kGemSkins.firstWhere((s) => s.price > 0); // aurora

  testWidgets('render tiêu đề + 2 mục + tên skin + nhãn EQUIPPED mặc định',
      (tester) async {
    await tester.pumpWidget(appEn(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('Gem Skins'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget); // skin mặc định
    expect(find.text(paidSkin.name), findsOneWidget); // skin trả phí
    expect(find.text('EQUIPPED'), findsWidgets); // classic đang dùng
    // mục theme bàn nằm dưới fold → cuộn tới để xác nhận render
    await tester.scrollUntilVisible(find.text('Board Themes'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Board Themes'), findsOneWidget);
    expect(find.text('Midnight'), findsOneWidget); // theme mặc định
  });

  testWidgets('đủ xu: bấm giá → mua + tự trang bị + dialog thành công',
      (tester) async {
    c.coins.value = 5000;
    await tester.pumpWidget(appEn(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('💰 ${paidSkin.price}'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // dialog hiện
    expect(c.isSkinOwned(paidSkin.id), isTrue);
    expect(c.selectedSkin.value, paidSkin.id);
    expect(c.coins.value, 5000 - paidSkin.price);
    // dialog neon thành công: tiêu đề là tên skin
    expect(find.text(paidSkin.name), findsWidgets);
  });

  testWidgets('thiếu xu: bấm giá → không mua + dialog neon (không snackbar)',
      (tester) async {
    c.coins.value = 0;
    await tester.pumpWidget(appEn(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('💰 ${paidSkin.price}'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.isSkinOwned(paidSkin.id), isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('not_enough_coins'.tr), findsOneWidget); // dialog neon
  });
}
