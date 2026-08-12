import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_info.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/logic/milestone_journal.dart';
import 'package:pop_star_blast/presentation/widgets/journey_card.dart';

/// I87 — `JourneyCard`: thẻ ảnh sẽ đi RA NGOÀI app.
///
/// Khác mọi màn hình khác ở đúng một điểm: sai ở đây thì lỗi không nằm trong
/// máy người chơi mà nằm trên dòng thời gian của bạn họ. Nên hai thứ được khoá
/// chặt nhất là **không có ô trống/"null"** và **không tràn bố cục**.
Future<void> _pump(
  WidgetTester tester, {
  String playerName = 'Roy',
  int totalStars = 123,
  int highestLevel = 45,
  int maxCombo = 9,
  int daysPlayed = 30,
  List<String>? lines,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: JourneyCard(
            playerName: playerName,
            totalStars: totalStars,
            highestLevel: highestLevel,
            maxCombo: maxCombo,
            daysPlayed: daysPlayed,
            milestoneLines: lines ?? const ['Mốc A', 'Mốc B'],
            mascotPalette: kMascotSkins.first.palette,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('render được, không ném', (tester) async {
    await _pump(tester);
    expect(find.byType(JourneyCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiện đủ mọi con số của hành trình', (tester) async {
    await _pump(tester);

    expect(find.text('123'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Roy'), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
  });

  testWidgets('hiện mọi dòng mốc được truyền vào', (tester) async {
    await _pump(tester, lines: const ['A', 'B', 'C']);

    for (final l in ['A', 'B', 'C']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  group('tên người chơi', () {
    testWidgets('rỗng -> dùng nhãn chung, KHÔNG để trống', (tester) async {
      await _pump(tester, playerName: '');

      expect(find.text('journey_card_anonymous'.tr), findsOneWidget);
      expect(find.text(''), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('toàn khoảng trắng cũng tính là rỗng', (tester) async {
      await _pump(tester, playerName: '   ');
      expect(find.text('journey_card_anonymous'.tr), findsOneWidget);
    });

    testWidgets('tên rất dài -> cắt bằng ellipsis, không tràn', (tester) async {
      await _pump(tester, playerName: 'A' * 200);

      final text = tester.widget<Text>(find.text('A' * 200));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('bố cục ảnh chia sẻ', () {
    testWidgets('vuông 1:1', (tester) async {
      await _pump(tester);
      final size = tester.getSize(find.byType(JourneyCard));
      expect(size.width, size.height);
    });

    testWidgets('đủ trần mốc vẫn không tràn', (tester) async {
      // Đây là ca dễ vỡ nhất: thẻ cao cố định, thêm dòng là tràn thẳng ra ảnh
      // chứ không chỉ là cảnh báo debug.
      await _pump(
        tester,
        lines: List.generate(kJourneyCardMilestones, (i) => 'Mốc số $i'),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('mốc có chữ rất dài vẫn không tràn', (tester) async {
      await _pump(
        tester,
        lines: List.generate(kJourneyCardMilestones, (_) => 'X' * 300),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('không có mốc nào vẫn dựng được', (tester) async {
      await _pump(tester, lines: const []);
      expect(find.byType(JourneyCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('số 0 hiện là 0, không phải ô trống', (tester) async {
      await _pump(
        tester,
        totalStars: 0,
        highestLevel: 0,
        maxCombo: 0,
        daysPlayed: 0,
      );

      expect(find.text('0'), findsNWidgets(4));
    });
  });
}
