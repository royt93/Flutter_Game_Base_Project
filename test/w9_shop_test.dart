import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 9 — Cửa hàng trang trí (skin gem + theme bàn). Kiểm logic mua/chọn,
/// thiếu xu, chọn item chưa sở hữu, mặc định sở hữu, persist & reset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  // id item miễn phí (mặc định) và item trả phí đầu tiên.
  final freeSkin = kGemSkins.first; // classic, price 0
  final paidSkin = kGemSkins.firstWhere((s) => s.price > 0); // aurora
  final freeTheme = kBoardThemes.first; // midnight
  final paidTheme = kBoardThemes.firstWhere((t) => t.price > 0);

  group('mặc định', () {
    test('item miễn phí sở hữu sẵn, đang trang bị; item trả phí chưa sở hữu', () {
      expect(c.isSkinOwned(freeSkin.id), isTrue);
      expect(c.isSkinOwned(paidSkin.id), isFalse);
      expect(c.selectedSkin.value, freeSkin.id);
      expect(c.isThemeOwned(freeTheme.id), isTrue);
      expect(c.selectedTheme.value, freeTheme.id);
      // holder tĩnh khớp lựa chọn mặc định
      expect(ActiveCosmetics.gemSkin.id, freeSkin.id);
      expect(ActiveCosmetics.boardTheme.id, freeTheme.id);
    });
  });

  group('mua skin', () {
    test('đủ xu → sở hữu + tự trang bị + trừ đúng xu + áp ActiveCosmetics', () {
      c.coins.value = paidSkin.price + 100;
      expect(c.buySkin(paidSkin.id), isTrue);
      expect(c.isSkinOwned(paidSkin.id), isTrue);
      expect(c.selectedSkin.value, paidSkin.id);
      expect(c.coins.value, 100);
      expect(ActiveCosmetics.gemSkin.id, paidSkin.id);
    });

    test('thiếu xu → false, không sở hữu, xu không đổi', () {
      c.coins.value = paidSkin.price - 1;
      expect(c.buySkin(paidSkin.id), isFalse);
      expect(c.isSkinOwned(paidSkin.id), isFalse);
      expect(c.coins.value, paidSkin.price - 1);
    });

    test('mua lại item đã sở hữu → false (không trừ xu)', () {
      c.coins.value = 5000;
      expect(c.buySkin(paidSkin.id), isTrue);
      final after = c.coins.value;
      expect(c.buySkin(paidSkin.id), isFalse);
      expect(c.coins.value, after);
    });
  });

  group('chọn skin', () {
    test('chọn item đã sở hữu → đổi trang bị + ActiveCosmetics', () {
      c.coins.value = 5000;
      c.buySkin(paidSkin.id); // giờ đang dùng paid
      c.selectSkin(freeSkin.id); // quay lại free (đã sở hữu)
      expect(c.selectedSkin.value, freeSkin.id);
      expect(ActiveCosmetics.gemSkin.id, freeSkin.id);
    });

    test('chọn item CHƯA sở hữu → không đổi', () {
      c.selectSkin(paidSkin.id);
      expect(c.selectedSkin.value, freeSkin.id);
    });
  });

  group('theme bàn', () {
    test('mua + chọn theme hoạt động giống skin', () {
      c.coins.value = paidTheme.price + 50;
      expect(c.buyTheme(paidTheme.id), isTrue);
      expect(c.isThemeOwned(paidTheme.id), isTrue);
      expect(c.selectedTheme.value, paidTheme.id);
      expect(ActiveCosmetics.boardTheme.id, paidTheme.id);
      expect(c.coins.value, 50);
    });

    test('chọn theme chưa sở hữu → không đổi', () {
      c.selectTheme(paidTheme.id);
      expect(c.selectedTheme.value, freeTheme.id);
    });
  });

  group('persist & reset', () {
    test('mua xong restart (reload) vẫn giữ sở hữu + lựa chọn', () async {
      c.coins.value = 5000;
      c.buySkin(paidSkin.id);
      c.buyTheme(paidTheme.id);
      await Future.delayed(const Duration(milliseconds: 20)); // unawaited setInt
      // reload controller (đọc lại từ đĩa)
      Get.delete<GameController>();
      final c2 = Get.put(GameController());
      expect(c2.isSkinOwned(paidSkin.id), isTrue);
      expect(c2.selectedSkin.value, paidSkin.id);
      expect(c2.isThemeOwned(paidTheme.id), isTrue);
      expect(c2.selectedTheme.value, paidTheme.id);
    });

    test('resetProgress xoá sở hữu skin/theme + đưa về mặc định', () async {
      c.coins.value = 5000;
      c.buySkin(paidSkin.id);
      c.buyTheme(paidTheme.id);
      await c.resetProgress();
      expect(c.isSkinOwned(paidSkin.id), isFalse);
      expect(c.selectedSkin.value, freeSkin.id);
      expect(c.isThemeOwned(paidTheme.id), isFalse);
      expect(c.selectedTheme.value, freeTheme.id);
      expect(ActiveCosmetics.gemSkin.id, freeSkin.id);
      expect(ActiveCosmetics.boardTheme.id, freeTheme.id);
    });
  });
}
