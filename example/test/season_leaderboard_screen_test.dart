import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/countdown_chip.dart';
import 'package:roy_casual_kit/presentation/widgets/common/leaderboard_list.dart';
import 'package:roy_casual_kit_example/screens/season_leaderboard_screen.dart';
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

  for (final rtl in [false, true]) {
    testWidgets(
        'no layout overflow at 2.0 text scale on a 360dp phone (rtl=$rtl)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _boot();

      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: AppTranslations.fallback,
        fallbackLocale: AppTranslations.fallback,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.0),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: const SeasonLeaderboardScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders SeasonLeaderboardScreen with countdown and empty leaderboard',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SeasonLeaderboardScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Season & Ranking'), findsWidgets);
    expect(find.byType(CountdownChip), findsOneWidget);
    expect(find.text('Season 1: Neon Dawn'), findsOneWidget);
    expect(find.text('Season Points: 0'), findsOneWidget);
    expect(find.text('Tier: 1'), findsOneWidget);
    expect(find.textContaining('No scores submitted yet'), findsOneWidget);
    expect(_button('Earn +25 Season Points'), findsOneWidget);
    expect(_button('Submit +500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earning season points updates points and tier', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SeasonLeaderboardScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final earnBtn = _button('Earn +25 Season Points').first;
    await tester.tap(earnBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Season Points: 25'), findsOneWidget);
    expect(find.textContaining('Earned +25 Season Points! Total: 25 pts.'), findsOneWidget);

    await tester.tap(earnBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Season Points: 50'), findsOneWidget);
    expect(find.text('Tier: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting score populates LeaderboardList', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SeasonLeaderboardScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final submitBtn = _button('Submit +500').first;
    await tester.tap(submitBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LeaderboardList), findsOneWidget);
    expect(find.text('Hero Player'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.textContaining('Submitted high score: 500!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
