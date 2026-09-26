import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_button.dart';
import 'package:roy_casual_kit_example/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => GetMaterialApp(
      translations: AppTranslations(),
      locale: AppTranslations.fallback,
      fallbackLocale: AppTranslations.fallback,
      home: child,
    );

void main() {
  tearDown(Get.reset);

  testWidgets('renders HomeScreen with all navigation buttons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );

    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Roy Casual Kit Example'), findsNWidgets(2));
    expect(find.byType(NeonButton), findsNWidgets(10));
    final labels = find
        .byType(NeonButton)
        .evaluate()
        .map((element) => (element.widget as NeonButton).label)
        .toSet();
    expect(
      labels,
      containsAll([
        'Settings',
        'Widget Kit',
        'Flame Demo',
        'Daily Rewards',
        'Shop',
        'Save & Cloud',
        'Level & Energy',
        'Season & Ranking',
        'Store & Monetization',
        'Cookbook',
      ]),
    );
    expect(tester.takeException(), isNull);
  });
}
