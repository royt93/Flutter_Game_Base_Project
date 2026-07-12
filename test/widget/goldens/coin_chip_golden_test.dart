import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/widgets/coin_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('CoinChip renders coin count', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.coins.value = 1234;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: Center(child: CoinChip(gameCtrl))),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(CoinChip),
      matchesGoldenFile('coin_chip.png'),
    );
    Get.reset();
  });
}
