import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';
import 'package:roy_casual_kit_example/screens/level_progression_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _button(String label) => find.byWidgetPredicate(
      (widget) => widget is CommonButton && widget.label == label,
    );

Widget _wrap(Widget child) => GetMaterialApp(
      translations: AppTranslations(),
      locale: AppTranslations.fallback,
      fallbackLocale: AppTranslations.fallback,
      home: child,
    );

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  Get.put(
    StorageService(await SharedPreferences.getInstance()),
    permanent: true,
  );
}

void main() {
  tearDown(Get.reset);

  testWidgets('renders LevelProgressionScreen with energy, progression, offline',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Level & Energy'), findsWidgets);
    expect(find.byType(EnergyBar), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Coins: 0'), findsOneWidget);
    expect(find.text('Idle Offline Production'), findsOneWidget);
    expect(_button('Play Stage (-1 Energy)'), findsOneWidget);
    expect(_button('Infinite Lives'), findsOneWidget);
    expect(_button('Claim Offline Earnings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play stage consumes energy, earns XP and coins', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final playBtn = _button('Play Stage (-1 Energy)').first;
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Stage cleared! +50 XP, +25 coins.'), findsOneWidget);
    expect(find.text('Coins: 25'), findsOneWidget);
    expect(find.textContaining('XP: 50 / 100'), findsOneWidget);
    expect(EnergyService.maybe!.currentEnergy, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exhausting energy blocks play and shows error message',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final energy = EnergyService.maybe!;
    while (energy.currentEnergy > 0) {
      energy.consumeEnergy(1);
    }
    expect(energy.currentEnergy, 0);

    final playBtn = _button('Play Stage (-1 Energy)').first;
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Not enough energy! Wait for refill or use infinite lives.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('infinite lives allows playing with 0 energy', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final energy = EnergyService.maybe!;
    while (energy.currentEnergy > 0) {
      energy.consumeEnergy(1);
    }

    final infiniteBtn = _button('Infinite Lives').first;
    await tester.tap(infiniteBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Granted 15 minutes of infinite energy!'), findsOneWidget);

    final playBtn = _button('Play Stage (-1 Energy)').first;
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Stage cleared!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim offline earnings with 0 pending shows notification',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final claimBtn = _button('Claim Offline Earnings').first;
    await tester.tap(claimBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('No offline earnings accumulated yet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim offline earnings sau 10 giây cộng coins vào ví và reset mốc',
      (tester) async {
    await _boot();
    final start = nowMsClamped(StorageService.to);
    await StorageService.to.setInt(
      StorageKeys.offlineLastClaimedMs,
      start - 10000,
    );

    await tester.pumpWidget(_wrap(const LevelProgressionScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(_button('Claim Offline Earnings').first);
    await tester.pump(const Duration(milliseconds: 500));

    final coins = EconomyWallet.maybe!.balanceOf('coins');
    // 10s * 2 coin/s = 20, cộng độ trễ test vài trăm ms (tối đa vài coin).
    expect(coins, inInclusiveRange(20, 30));
    expect(find.text('Coins: $coins'), findsOneWidget);
    expect(find.textContaining('Claimed $coins offline coins!'), findsOneWidget);
    expect(
      StorageService.to.getInt(StorageKeys.offlineLastClaimedMs),
      greaterThan(start - 10000),
    );

    await tester.tap(_button('Claim Offline Earnings').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining('No offline earnings accumulated yet'),
      findsOneWidget,
    );
    expect(EconomyWallet.maybe!.balanceOf('coins'), coins);
    expect(tester.takeException(), isNull);
  });
}
