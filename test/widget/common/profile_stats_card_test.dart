import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

List<ProfileStat> _stats(int count) => [
  for (var i = 0; i < count; i++)
    ProfileStat(
      label: 'Stat $i',
      valueText: '${i * 10}K',
      icon: Icons.star_rounded,
    ),
];

Widget subject({
  String name = 'Maya Rose',
  String? title = 'Explorer',
  bool withLevel = true,
  int level = 12,
  int xp = 60,
  List<ProfileStat> stats = const [],
  VoidCallback? onTap,
  VoidCallback? onEditAvatar,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ProfileStatsCard(
            name: name,
            title: title,
            avatar: const Icon(Icons.face),
            level: withLevel
                ? ProfileLevel(level: level, currentXp: xp, xpForNextLevel: 100)
                : null,
            stats: stats,
            onTap: onTap,
            onEditAvatar: onEditAvatar,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates profile, level and stat boundaries at runtime', () {
    expect(
      () => ProfileStatsCard(name: ' ', avatar: const SizedBox()),
      throwsArgumentError,
    );
    expect(
      () => ProfileStatsCard(
        name: 'Maya',
        avatar: const SizedBox(),
        stats: _stats(5),
      ),
      throwsArgumentError,
    );
    expect(() => ProfileStat(label: ' ', valueText: '1'), throwsArgumentError);
    expect(
      () => ProfileStat(label: 'Wins', valueText: ' '),
      throwsArgumentError,
    );
    expect(() => ProfileLevel(level: 0, currentXp: 0), throwsArgumentError);
    expect(() => ProfileLevel(level: 2, currentXp: -1), throwsArgumentError);
    expect(
      () => ProfileLevel(level: 2, currentXp: 11, xpForNextLevel: 10),
      throwsArgumentError,
    );
    expect(
      () => ProfileLevel(level: 2, currentXp: 0, xpForNextLevel: 0),
      throwsArgumentError,
    );
    expect(
      () => ProfileStatsCard(
        name: 'Maya',
        avatar: const SizedBox(),
        stats: [
          ProfileStat(label: 'Wins', valueText: '1'),
          ProfileStat(label: 'Wins', valueText: '2'),
        ],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('shows complete data and 0/2/4-stat layouts', (tester) async {
    for (final count in [0, 2, 4]) {
      await tester.pumpWidget(subject(stats: _stats(count)));
      expect(find.text('Maya Rose'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Lv 12'), findsOneWidget);
      expect(find.byType(AvatarFrame), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profileStat_Stat 0')),
        count == 0 ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('optional fields render cleanly', (tester) async {
    await tester.pumpWidget(
      subject(title: null, withLevel: false, stats: _stats(0)),
    );
    expect(find.text('Explorer'), findsNothing);
    expect(find.text('Lv 12'), findsNothing);
    expect(find.byType(AvatarFrame), findsOneWidget);
  });

  testWidgets('card tap routes to caller', (tester) async {
    var taps = 0;
    await tester.pumpWidget(subject(onTap: () => taps++));
    await tester.tap(find.text('Maya Rose'));
    expect(taps, 1);
  });

  testWidgets('edit avatar tap does not also trigger card tap', (tester) async {
    var cardTaps = 0;
    var editTaps = 0;
    await tester.pumpWidget(
      subject(onTap: () => cardTaps++, onEditAvatar: () => editTaps++),
    );
    await tester.tap(find.byKey(const ValueKey('profileStatsEditAvatar')));
    expect(editTaps, 1);
    expect(cardTaps, 0);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('profileStatsEditAvatar')))
          .shortestSide,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('semantics include identity, level, stats and edit action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        subject(stats: _stats(2), onTap: () {}, onEditAvatar: () {}),
      );
      final cardNode = tester.getSemantics(find.byType(ProfileStatsCard));
      expect(cardNode.label, contains('Maya Rose, Explorer'));
      expect(cardNode.label, contains('level 12'));
      expect(cardNode.label, contains('Stat 0 0K'));
      expect(cardNode.label, contains('Stat 1 10K'));
      expect(
        cardNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('profileStatsEditAvatar')))
            .label,
        'Edit avatar',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('long identity and stats fit 320dp at 2x text in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        name: 'An Extraordinarily Long Player Display Name',
        title: 'A Very Long Profile Title',
        stats: _stats(4),
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(ProfileStatsCard))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates values without crash, unmounts without ticker', (
    tester,
  ) async {
    for (var i = 1; i <= 10; i++) {
      await tester.pumpWidget(
        subject(name: 'Maya $i', level: 12, xp: i * 5, stats: _stats(i % 5)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('Maya 10'), findsOneWidget);
    expect(find.text('Lv 12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
