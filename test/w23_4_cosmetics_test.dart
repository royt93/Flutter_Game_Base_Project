import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 23.4 — gem skin + board theme mới (coin-sink): tồn tại, hợp lệ, mua được.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  GemSkin skin(String id) => kGemSkins.firstWhere((s) => s.id == id);
  BoardTheme theme(String id) => kBoardThemes.firstWhere((t) => t.id == id);

  group('content mới tồn tại + hợp lệ', () {
    test('skin mới: galaxy / neon_pop / gold_lux', () {
      for (final id in ['galaxy', 'neon_pop', 'gold_lux']) {
        final s = skin(id);
        expect(s.colors.length, 6, reason: '$id phải đủ 6 màu');
        expect(s.shapeFamily, inInclusiveRange(0, 2));
        expect(s.price, greaterThan(0)); // trả phí (coin-sink)
      }
    });
    test('theme mới: nebula / lava / cyberpunk trả phí', () {
      for (final id in ['nebula', 'lava', 'cyberpunk']) {
        expect(theme(id).price, greaterThan(0));
      }
    });
    test('mọi id skin & theme là DUY NHẤT', () {
      final skinIds = kGemSkins.map((s) => s.id).toList();
      final themeIds = kBoardThemes.map((t) => t.id).toList();
      expect(skinIds.toSet().length, skinIds.length);
      expect(themeIds.toSet().length, themeIds.length);
    });
  });

  group('mua / sở hữu', () {
    test('mặc định: skin/theme mới CHƯA sở hữu, classic sở hữu sẵn', () {
      expect(g.isSkinOwned('galaxy'), isFalse);
      expect(g.isThemeOwned('nebula'), isFalse);
      expect(g.isSkinOwned(kGemSkins.first.id), isTrue); // classic free
    });

    test('đủ xu → mua skin galaxy thành công + trừ xu + trang bị', () {
      final price = skin('galaxy').price;
      // đảm bảo đủ xu
      g.addCoins(price + 100);
      final before = g.coins.value;
      expect(g.buySkin('galaxy'), isTrue);
      expect(g.isSkinOwned('galaxy'), isTrue);
      expect(g.coins.value, before - price);
      expect(g.selectedSkin.value, 'galaxy');
    });

    test('thiếu xu → mua gold_lux thất bại, không sở hữu', () {
      // ép xu về dưới giá
      while (g.coins.value > 0) {
        g.spendCoins(g.coins.value);
      }
      expect(g.buySkin('gold_lux'), isFalse);
      expect(g.isSkinOwned('gold_lux'), isFalse);
    });

    test('đủ xu → mua theme cyberpunk thành công', () {
      g.addCoins(theme('cyberpunk').price + 100);
      expect(g.buyTheme('cyberpunk'), isTrue);
      expect(g.isThemeOwned('cyberpunk'), isTrue);
      expect(g.selectedTheme.value, 'cyberpunk');
    });
  });

  test('resetProgress → content mới về CHƯA sở hữu', () async {
    g.addCoins(5000);
    g.buySkin('galaxy');
    g.buyTheme('nebula');
    await g.resetProgress();
    expect(g.isSkinOwned('galaxy'), isFalse);
    expect(g.isThemeOwned('nebula'), isFalse);
  });
}
