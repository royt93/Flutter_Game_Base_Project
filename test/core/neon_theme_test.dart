import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/pigments.dart';

void main() {
  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
  });

  tearDown(Get.reset);

  test('resolvedGemColor uses a persisted pigment override', () async {
    await StorageService.to.setString(
      StorageKeys.gemColorOverrides,
      encodeGemColorOverrides({2: 'coral'}),
    );

    expect(resolvedGemColor(2), kPigments[1].color);
  });

  test('resolvedGemColor falls back with the original modulo behavior', () {
    final index = NeonTheme.gemColors.length + 3;
    expect(resolvedGemColor(index), NeonTheme.gemColors[3]);
  });
}
