import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/presentation/screens/guide_screen.dart';

void main() {
  testWidgets('render đủ 6 rule luật chơi, không lỗi', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const GuideScreen(),
      ),
    );
    // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    // Title đi qua NeonAppBar -> StrokeText, vẽ 2 lớp (stroke + fill).
    expect(find.text('How To Play'), findsNWidgets(2));
    expect(find.text('Tap a group'), findsOneWidget);
    expect(find.text('No moves left'), findsOneWidget);
    // I29: rule mới giới thiệu boss tile ở màn mốc — là rule thứ 6 (cuối
    // danh sách), nằm ngoài viewport ban đầu nên phải cuộn ListView xuống
    // trước khi tìm thấy.
    await tester.dragUntilVisible(
      find.text('Boss Tile'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Boss Tile'), findsOneWidget);
  });
}
