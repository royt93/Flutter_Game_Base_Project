import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mở app, chọn level, chơi 1 tap, thoát về danh sách level', (
    tester,
  ) async {
    await app.app(withAudio: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelSelectScreen), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });
}
