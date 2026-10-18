import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget subject({
  String? message = 'Ready for the team event?',
  int count = 3,
  bool reducedMotion = false,
  double textScale = 1,
  VoidCallback? onTap,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClanChatPreviewBar(
            senderName: message == null ? null : 'Maya Rose',
            message: message,
            timestampText: '2m ago',
            unreadCount: count,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('rejects invalid counts, partial messages and blank labels', () {
    for (final create in <ClanChatPreviewBar Function()>[
      () => ClanChatPreviewBar(onTap: () {}, unreadCount: -1),
      () => ClanChatPreviewBar(onTap: () {}, message: 'Hi'),
      () => ClanChatPreviewBar(onTap: () {}, senderName: 'Maya'),
      () => ClanChatPreviewBar(onTap: () {}, senderName: ' ', message: 'Hi'),
      () => ClanChatPreviewBar(onTap: () {}, senderName: 'Maya', message: ' '),
      () => ClanChatPreviewBar(onTap: () {}, emptyMessage: ' '),
      () => ClanChatPreviewBar(onTap: () {}, semanticLabel: ' '),
    ]) {
      expect(create, throwsArgumentError);
    }
  });

  testWidgets('shows latest message, avatar and caller timestamp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClanChatPreviewBar(
          senderName: 'Maya',
          message: 'Hi team',
          timestampText: 'Now',
          senderAvatar: const Icon(Icons.face),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Hi team'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.byIcon(Icons.face), findsOneWidget);
    final text = tester.widget<Text>(find.text('Hi team'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('hides zero count and caps only displayed count at 99+', (
    tester,
  ) async {
    for (final count in [0, 1, 99, 100, 1000]) {
      await tester.pumpWidget(subject(count: count));
      expect(
        find.byKey(const ValueKey('clanChatUnreadBadge')),
        count == 0 ? findsNothing : findsOneWidget,
      );
      if (count > 0) {
        expect(find.text(count > 99 ? '99+' : '$count'), findsOneWidget);
      }
    }
  });

  testWidgets('empty state still opens caller chat with 48dp target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      subject(message: null, count: 0, onTap: () => taps++),
    );
    expect(find.text('No messages yet'), findsOneWidget);
    final target = find.byKey(const ValueKey('clanChatPreviewTap'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(taps, 1);
  });

  testWidgets('semantics includes full message, actual count and tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      var taps = 0;
      await tester.pumpWidget(subject(count: 120, onTap: () => taps++));
      final node = tester.getSemantics(find.byType(ClanChatPreviewBar));
      expect(
        node,
        matchesSemantics(
          label:
              'Clan chat, Maya Rose: Ready for the team event?, 2m ago, 120 unread',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ClanChatPreviewBar));
      expect(taps, 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, RTL and 2x text preserve layout', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(count: 120, textScale: 2, direction: TextDirection.rtl),
    );
    expect(
      Directionality.of(tester.element(find.byType(ClanChatPreviewBar))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid updates, reduced motion and unmount leave no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    for (var i = 0; i < 30; i++) {
      await tester.pumpWidget(subject(message: 'Message $i', count: i + 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Message 29'), findsOneWidget);
    await tester.pumpWidget(subject(reducedMotion: true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
