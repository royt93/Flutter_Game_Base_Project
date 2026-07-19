import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/widgets/ambient_weather_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setUpStorage(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  await StorageService.to.setBool(StorageKeys.reduceMotion, reduceMotion);
}

void main() {
  tearDown(Get.reset);

  for (final kind in WeatherKind.values) {
    testWidgets('build không lỗi với WeatherKind.$kind', (tester) async {
      await _setUpStorage(tester);
      await tester.pumpWidget(
        MaterialApp(home: AmbientWeatherLayer(weather: kind)),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('weather == none không vẽ particle nào (SizedBox.shrink)', (
    tester,
  ) async {
    await _setUpStorage(tester);
    await tester.pumpWidget(
      const MaterialApp(home: AmbientWeatherLayer(weather: WeatherKind.none)),
    );

    expect(
      find.descendant(
        of: find.byType(AmbientWeatherLayer),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'reduce-motion tắt: animation lặp vô hạn (.repeat()) không bao giờ '
    'settle',
    (tester) async {
      await _setUpStorage(tester, reduceMotion: false);
      await tester.pumpWidget(
        const MaterialApp(home: AmbientWeatherLayer(weather: WeatherKind.snow)),
      );

      expect(
        () => tester.pumpAndSettle(const Duration(milliseconds: 100)),
        throwsFlutterError,
      );
    },
  );

  testWidgets('reduce-motion bật: không gọi .repeat() nên settle bình thường', (
    tester,
  ) async {
    await _setUpStorage(tester, reduceMotion: true);
    await tester.pumpWidget(
      const MaterialApp(home: AmbientWeatherLayer(weather: WeatherKind.snow)),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
