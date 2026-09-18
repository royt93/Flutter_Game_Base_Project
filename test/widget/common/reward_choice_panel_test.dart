import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/presentation/widgets/common/async_common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_choice_panel.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

const _options = [
  RewardChoiceOption(
    id: 'coin',
    label: 'Coin pack',
    lines: [RewardLine(currency: 'coin', amount: 50)],
  ),
  RewardChoiceOption(
    id: 'gem',
    label: 'Gem pack',
    lines: [RewardLine(currency: 'gem', amount: 5)],
  ),
  RewardChoiceOption(
    id: 'booster',
    label: 'Booster',
    locked: true,
    lockedReason: 'Reach level 10',
  ),
];

void main() {
  testWidgets('hiện đúng label mọi option', (tester) async {
    await tester.pumpWidget(
      _wrap(RewardChoicePanel(options: _options, onConfirm: (_) async {})),
    );

    expect(find.text('Coin pack'), findsOneWidget);
    expect(find.text('Gem pack'), findsOneWidget);
    expect(find.text('Booster'), findsOneWidget);
    expect(find.text('Reach level 10'), findsOneWidget);
  });

  testWidgets('option locked không chọn được', (tester) async {
    await tester.pumpWidget(
      _wrap(RewardChoicePanel(options: _options, onConfirm: (_) async {})),
    );

    await tester.tap(find.text('Booster'));
    await tester.pump();

    // Confirm vẫn disabled vì chưa chọn được option nào hợp lệ.
    final button = tester.widget<AsyncCommonButton>(
      find.byType(AsyncCommonButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('single-select: chọn option mới thay thế option cũ', (
    tester,
  ) async {
    List<String>? confirmedIds;
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(
          options: _options,
          onConfirm: (ids) async => confirmedIds = ids,
        ),
      ),
    );

    await tester.tap(find.text('Coin pack'));
    await tester.pump();
    await tester.tap(find.text('Gem pack'));
    await tester.pump();

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(confirmedIds, ['gem']);
  });

  testWidgets('multi-select: chọn tới maxSelectable, vượt quá bị bỏ qua', (
    tester,
  ) async {
    List<String>? confirmedIds;
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(
          options: _options,
          multiSelect: true,
          maxSelectable: 1,
          onConfirm: (ids) async => confirmedIds = ids,
        ),
      ),
    );

    await tester.tap(find.text('Coin pack'));
    await tester.pump();
    await tester.tap(find.text('Gem pack')); // vượt max=1 -> bị bỏ qua
    await tester.pump();

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(confirmedIds, ['coin']);
  });

  testWidgets('minSelectable chưa đạt: nút confirm disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(
          options: _options,
          multiSelect: true,
          minSelectable: 2,
          onConfirm: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Coin pack'));
    await tester.pump();

    var button = tester.widget<AsyncCommonButton>(
      find.byType(AsyncCommonButton),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Gem pack'));
    await tester.pump();

    button = tester.widget<AsyncCommonButton>(find.byType(AsyncCommonButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('rapid double-tap confirm chỉ gọi onConfirm đúng 1 lần', (
    tester,
  ) async {
    var callCount = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(
          options: _options,
          onConfirm: (_) {
            callCount++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Coin pack'));
    await tester.pump();
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(callCount, 1);
    completer.complete();
    await tester.pump();
  });

  testWidgets('confirm thành công: panel chuyển claimed, không chọn/confirm lại được', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(options: _options, onConfirm: (_) async {}),
      ),
    );

    await tester.tap(find.text('Coin pack'));
    await tester.pump();
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200)); // qua successDuration

    expect(find.byType(AsyncCommonButton), findsNothing);
    expect(find.text('Claimed'), findsWidgets);
  });

  testWidgets('claimedIds truyền sẵn: hiện read-only claimed, không có nút confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RewardChoicePanel(
          options: _options,
          claimedIds: const {'coin'},
          onConfirm: (_) async {},
        ),
      ),
    );

    expect(find.byType(AsyncCommonButton), findsNothing);
    expect(find.text('Claimed'), findsWidgets);

    await tester.tap(find.text('Gem pack'));
    await tester.pump();
    expect(find.byType(AsyncCommonButton), findsNothing); // vẫn không hiện
  });

  testWidgets('options rỗng: hiện empty state, không throw', (tester) async {
    await tester.pumpWidget(
      _wrap(RewardChoicePanel(options: const [], onConfirm: (_) async {})),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('id trùng nhau trong debug mode throw assertion error', (
    tester,
  ) async {
    expect(
      () => RewardChoicePanel(
        options: const [
          RewardChoiceOption(id: 'a', label: 'A'),
          RewardChoiceOption(id: 'a', label: 'A2'),
        ],
        onConfirm: (_) async {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('RTL + text scale lớn không throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Material(
              child: RewardChoicePanel(
                options: _options,
                onConfirm: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
