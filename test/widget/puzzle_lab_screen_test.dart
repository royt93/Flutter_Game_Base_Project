import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/puzzle_code.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/puzzle_lab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  // Màn hình dài (nhiều stepper + grid + saved list) → phóng viewport đủ cao
  // để mọi nút bấm nằm trong tầm nhìn, tránh lỗi hit-test do cuộn dở dang.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      home: const PuzzleLabScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Finder get _gridCells => find.descendant(
  of: find.byType(GridView),
  matching: find.byType(GestureDetector),
);

Finder get _addRows => find.byIcon(Icons.add_circle_outline).at(0);
Finder get _addCols => find.byIcon(Icons.add_circle_outline).at(1);

Color _cellColorAt(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find.descendant(of: _gridCells.at(index), matching: find.byType(Container)),
  );
  return (container.decoration as BoxDecoration).color!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> initServices() async {
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);
  }

  testWidgets('đổi rows/cols/colors qua UI → grid rebuild đúng kích thước', (
    tester,
  ) async {
    await initServices();
    await _pumpScreen(tester);

    expect(_gridCells, findsNWidgets(8 * 6));

    await tester.tap(_addRows);
    await tester.pump();
    expect(_gridCells, findsNWidgets(9 * 6));

    await tester.tap(_addCols);
    await tester.pump();
    expect(_gridCells, findsNWidgets(9 * 7));

    expect(tester.takeException(), isNull);
  });

  testWidgets('tap 1 ô nhiều lần → xoay vòng đúng thứ tự màu', (tester) async {
    await initServices();
    await _pumpScreen(tester);

    // colorCount mặc định = 4: null->0->1->2->3->-1(obstacle)->gift->null.
    expect(_cellColorAt(tester, 0), NeonTheme.card);

    for (final expected in [
      NeonTheme.gemColors[0],
      NeonTheme.gemColors[1],
      NeonTheme.gemColors[2],
      NeonTheme.gemColors[3],
      NeonTheme.inkSoft,
      NeonTheme.gold,
      NeonTheme.card,
    ]) {
      await tester.tap(_gridCells.at(0));
      await tester.pump();
      expect(_cellColorAt(tester, 0), expected);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Save khi có ≥1 gem → lưu thêm 1 code hợp lệ vào storage', (
    tester,
  ) async {
    await initServices();
    await _pumpScreen(tester);

    await tester.tap(_gridCells.at(0)); // vẽ 1 gem màu 0
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await tester.pump();

    final saved = StorageService.to.getStringList(StorageKeys.savedPuzzles);
    expect(saved, hasLength(1));
    final decoded = decodePuzzleGrid(saved.first);
    expect(decoded, isNotNull);
    expect(hasAnyGem(decoded!), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lưu quá 5 bàn → chỉ giữ 5, bàn cũ nhất bị xoá', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.savedPuzzles: jsonEncode(List.generate(5, (i) => 'seed_$i')),
    });
    await initServices();
    await _pumpScreen(tester);

    await tester.tap(_gridCells.at(0));
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await tester.pump();

    final saved = StorageService.to.getStringList(StorageKeys.savedPuzzles);
    expect(saved, hasLength(5));
    expect(saved.contains('seed_0'), isFalse); // bàn cũ nhất bị xoá
    expect(saved.contains('seed_1'), isTrue);
    final decoded = decodePuzzleGrid(saved.last);
    expect(decoded, isNotNull);
    expect(hasAnyGem(decoded!), isTrue);
  });

  testWidgets(
    'Share khi bàn rỗng → không crash, không gọi shareText, hiện lỗi',
    (tester) async {
      await initServices();
      await _pumpScreen(tester);

      await tester.tap(find.text('Share code').first);
      await tester.pump();

      expect(
        find.text('Add at least one colored gem before playing'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nhập mã hợp lệ có gem + Play → navigate GameScreen', (
    tester,
  ) async {
    await initServices();
    await _pumpScreen(tester);

    final grid = List.generate(8, (_) => List<int?>.filled(6, null));
    grid[0][0] = 0;
    final code = encodePuzzleGrid(grid);

    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Play custom board').first);
    // Get.to() cần 2 pump: 1 để push route, 1 nữa để GameScreen thực sự
    // build/mount trong cây widget (chỉ 1 pump chưa đủ, tương tự pattern
    // navigate ở các test khác trong repo dùng Get.to).
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nhập chuỗi rác + Play → hiện lỗi, không navigate', (
    tester,
  ) async {
    await initServices();
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'not-a-valid-code!!');
    await tester.tap(find.text('Play custom board').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Invalid or empty puzzle code'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mã hợp lệ về định dạng nhưng bàn rỗng toàn gem → chặn chơi, hiện lỗi',
    (tester) async {
      await initServices();
      await _pumpScreen(tester);

      final emptyGrid = List.generate(8, (_) => List<int?>.filled(6, null));
      final code = encodePuzzleGrid(emptyGrid);

      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('Play custom board').first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Invalid or empty puzzle code'), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
