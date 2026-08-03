import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/presentation/widgets/score_card.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I57 Shareable Score Card: chỉ test build widget với dữ liệu truyền qua
// constructor — không test phần capture PNG/share thật (xem share_helper.dart).
void main() {
  testWidgets('hiện điểm, tổng sao và ẩn rank khi rank == null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Material(
          child: ScoreCard(
            score: 1234,
            totalStars: 42,
            mascotPalette: classicMascotPalette,
          ),
        ),
      ),
    );

    expect(find.textContaining('1234'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('Rank'), findsNothing);
  });

  testWidgets('hiện dòng rank khi rank != null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Material(
          child: ScoreCard(
            score: 500,
            totalStars: 10,
            mascotPalette: classicMascotPalette,
            rank: 3,
          ),
        ),
      ),
    );

    expect(find.textContaining('3'), findsWidgets);
    expect(find.textContaining('Rank'), findsOneWidget);
  });
}
