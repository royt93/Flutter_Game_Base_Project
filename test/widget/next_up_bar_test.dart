import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/logic/next_action.dart';
import 'package:pop_star_blast/presentation/widgets/next_up_bar.dart';

/// I84 — phần hiển thị. `NextUpBar` thuần trình bày: nhận danh sách đã xếp
/// hạng sẵn và callback, không tự đọc state. Nên test ở đây chỉ lo 3 việc:
/// hiện đúng nhãn, tap đúng mục, và **không để trống** khi không có gợi ý nào.
Future<void> _pump(
  WidgetTester tester,
  List<NextAction> actions, {
  void Function(NextAction)? onTap,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: NextUpBar(actions: actions, onTap: onTap ?? (_) {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  tearDown(Get.reset);

  testWidgets('luôn hiện tiêu đề khu vực', (tester) async {
    await _pump(tester, const []);
    expect(find.text('home_next_title'.tr), findsOneWidget);
  });

  testWidgets('không có gợi ý -> hiện dòng thân thiện, KHÔNG để trống', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.byKey(const Key('next_up_empty')), findsOneWidget);
    expect(find.text('home_next_empty'.tr), findsOneWidget);
  });

  testWidgets('render đủ mọi loại gợi ý, không ném', (tester) async {
    for (final kind in NextActionKind.values) {
      await _pump(tester, [NextAction(kind, value: 3)]);
      expect(
        find.byKey(Key('next_up_${kind.name}')),
        findsOneWidget,
        reason: 'thiếu chip cho $kind',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('hiện đúng 3 chip khi có 3 gợi ý', (tester) async {
    await _pump(tester, const [
      NextAction(NextActionKind.dailyReward),
      NextAction(NextActionKind.dailySpin),
      NextAction(NextActionKind.campaignLevel, value: 12),
    ]);
    expect(find.byKey(const Key('next_up_dailyReward')), findsOneWidget);
    expect(find.byKey(const Key('next_up_dailySpin')), findsOneWidget);
    expect(find.byKey(const Key('next_up_campaignLevel')), findsOneWidget);
    expect(find.byKey(const Key('next_up_empty')), findsNothing);
  });

  testWidgets('campaign hiện số màn kèm theo', (tester) async {
    await _pump(tester, const [
      NextAction(NextActionKind.campaignLevel, value: 42),
    ]);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('quest hiện số quest đã xong', (tester) async {
    await _pump(tester, const [
      NextAction(NextActionKind.dailyQuest, value: 2),
    ]);
    expect(find.textContaining('2'), findsOneWidget);
  });

  testWidgets('tap trả về đúng action đã bấm', (tester) async {
    NextAction? tapped;
    await _pump(tester, const [
      NextAction(NextActionKind.dailyReward),
      NextAction(NextActionKind.weeklyGoal),
    ], onTap: (a) => tapped = a);

    await tester.tap(find.byKey(const Key('next_up_weeklyGoal')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      tapped,
      const NextAction(NextActionKind.weeklyGoal),
      reason:
          'bấm chip nào phải trả đúng chip đó, không phải chip đầu danh sách',
    );
  });

  testWidgets('không lộ raw i18n key nào', (tester) async {
    await _pump(tester, [
      for (final k in NextActionKind.values) NextAction(k, value: 1),
    ]);
    expect(
      find.textContaining('home_next_'),
      findsNothing,
      reason: 'chuỗi chưa dịch sẽ hiện nguyên key ra màn hình',
    );
  });
}
