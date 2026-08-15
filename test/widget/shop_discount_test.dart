import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/shop_screen.dart';
import 'package:pop_star_blast/presentation/widgets/pressable_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shop khi perk giảm giá (Merchant Star, [[I83]]) đang bật.
///
/// Bug đã có trước file này: mỗi dòng shop nhận `price` và `canAfford` **rời
/// nhau**, và cả 7 dòng đều truyền giá GỐC cho cả hai, trong khi `buyBomb()`
/// trừ theo `discountedPrice`. Hậu quả:
///
/// * hiện sai số tiền phải trả (60 thay vì 51),
/// * khoá nút với người chơi có đủ tiền theo giá thật (55 xu vẫn mua được).
///
/// `_BoosterRow` giờ tự suy `canAfford` từ `price`, nên hai con số không thể
/// lệch nhau nữa; file này canh cả hai triệu chứng.
late GameController ctrl;

/// Bật perk giảm giá: cần prestige tier >= 1 **và** chòm sao đầu đã sáng
/// (20 sao), rồi chọn perk vào danh sách active.
void _enableDiscountPerk() {
  ctrl.prestigeTier.value = 1;
  ctrl.totalStars.value = 60;
  ctrl.activePerkIds.add('pp_discount');
}

Future<void> _pumpShop(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      home: const ShopScreen(),
    ),
  );
  // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
  addTearDown(Get.reset);
}

/// Nút mua là `PressableScale` bọc quanh chữ giá. Tìm theo `find.text` trần
/// sẽ trúng cả chip xu trên thanh trên cùng khi số xu tình cờ bằng giá.
Finder _buyButton(int price) => find.widgetWithText(PressableScale, '$price');

void main() {
  const raw = GameController.bombPrice;

  /// Giá gốc của cả 7 dòng shop — cần để biết một con số hiện trên màn là
  /// "giá gốc còn sót" hay chỉ là giá đã giảm của dòng khác.
  const rawPrices = [
    GameController.bombPrice,
    GameController.shufflePrice,
    GameController.undoPrice,
    GameController.rainbowPrice,
    GameController.swapPrice,
    GameController.freezePrice,
    GameController.streakFreezePrice,
  ];

  testWidgets('không perk: hiện đúng giá gốc', (tester) async {
    await _boot(tester);
    ctrl.coins.value = 1000;
    await _pumpShop(tester);

    expect(
      ctrl.discountedPrice(raw),
      raw,
      reason: 'chưa bật perk thì không giảm',
    );
    expect(find.text('$raw'), findsWidgets);
  });

  testWidgets('có perk: hiện GIÁ ĐÃ GIẢM, không phải giá gốc', (tester) async {
    await _boot(tester);
    ctrl.coins.value = 1000;
    _enableDiscountPerk();
    await _pumpShop(tester);

    final discounted = ctrl.discountedPrice(raw);
    expect(discounted, lessThan(raw), reason: 'perk phải thật sự giảm giá');
    expect(
      find.text('$discounted'),
      findsWidgets,
      reason: 'shop phải hiện số tiền người chơi THẬT SỰ bị trừ',
    );
    // Không so trần `find.text('$raw')`: giá GỐC của dòng này (60) tình cờ
    // trùng giá ĐÃ GIẢM của dòng freeze (70 -> 60), nên con số đó vẫn phải
    // xuất hiện. Chỉ bắt những giá gốc không trùng giá giảm của bất kỳ dòng
    // nào — chúng mà hiện lên thì đúng là còn sót.
    final discountedAll = rawPrices.map(ctrl.discountedPrice).toSet();
    var checked = 0;
    for (final price in rawPrices) {
      if (discountedAll.contains(price)) continue;
      checked++;
      expect(
        find.text('$price'),
        findsNothing,
        reason: 'hiện giá gốc $price là nói dối người chơi có perk',
      );
    }
    // Không có dòng này thì vòng trên có thể bỏ qua sạch (hoặc so nhầm chuỗi
    // literal) mà ca test vẫn xanh — đúng lỗi bản nháp đầu đã mắc.
    expect(checked, greaterThanOrEqualTo(5));
  });

  testWidgets('có perk: đủ tiền theo giá giảm thì nút phải bấm được', (
    tester,
  ) async {
    await _boot(tester);
    _enableDiscountPerk();
    final discounted = ctrl.discountedPrice(raw);
    // Nằm GIỮA giá giảm và giá gốc — đúng vùng mà bản cũ khoá nhầm.
    ctrl.coins.value = discounted;
    expect(ctrl.coins.value, lessThan(raw));

    await _pumpShop(tester);
    final before = ctrl.bombCount.value;

    await tester.tap(_buyButton(discounted));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(
      ctrl.bombCount.value,
      before + 1,
      reason: 'đủ tiền theo giá thật mà nút vẫn khoá = người chơi bị chặn oan',
    );
    expect(ctrl.coins.value, 0);
  });

  testWidgets('thiếu 1 xu so với giá giảm thì KHÔNG mua được', (tester) async {
    await _boot(tester);
    _enableDiscountPerk();
    final discounted = ctrl.discountedPrice(raw);
    ctrl.coins.value = discounted - 1;

    await _pumpShop(tester);
    final before = ctrl.bombCount.value;

    await tester.tap(_buyButton(discounted), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ctrl.bombCount.value, before, reason: 'không được cộng booster');
    expect(ctrl.coins.value, discounted - 1, reason: 'không được trừ xu');
  });
}
