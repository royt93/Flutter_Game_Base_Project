import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/daily_login_calendar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/quest_board_panel.dart';
import 'package:roy_casual_kit_example/screens/daily_reward_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _button(String label) => find.widgetWithText(CommonButton, label);

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

  testWidgets('renders DailyLoginCalendarWidget and QuestBoardPanel', (
    tester,
  ) async {
    await _boot();

    await tester.pumpWidget(_wrap(const DailyRewardScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Daily Rewards'), findsWidgets);
    expect(find.textContaining('Wallet: coins 0 | gems 0'), findsOneWidget);
    expect(find.byType(DailyLoginCalendarWidget), findsOneWidget);
    expect(find.byType(QuestBoardPanel), findsOneWidget);
    expect(_button('Play training tap'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim daily login reward adds coins once', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const DailyRewardScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('Claim +50 coins').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Wallet: coins 50 | gems 0'), findsOneWidget);
    expect(find.textContaining('Day 1 claimed: +50 coins.'), findsOneWidget);
    expect(EconomyWallet.maybe!.balanceOf('coins'), 50);

    await tester.tap(_button('Claim +50 coins').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(EconomyWallet.maybe!.balanceOf('coins'), 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three training taps complete quest and claim adds gems once', (
    tester,
  ) async {
    await _boot();

    await tester.pumpWidget(_wrap(const DailyRewardScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    for (var i = 0; i < 3; i++) {
      await tester.tap(_button('Play training tap').first);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.textContaining('Quest complete. Claim +5 gems.'),
      findsOneWidget,
    );
    final claimButton = _button('Claim +5 gems').first;
    await tester.ensureVisible(claimButton);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(claimButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Wallet: coins 0 | gems 5'), findsOneWidget);
    expect(
      find.textContaining('Quest reward claimed: +5 gems.'),
      findsOneWidget,
    );
    expect(EconomyWallet.maybe!.balanceOf('gems'), 5);

    expect(find.text('Đã nhận'), findsWidgets);
    await tester.tap(_button('Đã nhận').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(EconomyWallet.maybe!.balanceOf('gems'), 5);
    expect(tester.takeException(), isNull);
  });
}
