import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget _subject({
  String title = 'Welcome Gift',
  String body = 'Here is your starter pack of gems and coins!',
  String? receivedLabel = 'Today',
  bool isRead = false,
  bool isClaimed = false,
  List<InboxAttachment> attachments = const [
    InboxAttachment(icon: Icons.diamond_rounded, label: 'Gems', amount: 50),
    InboxAttachment(
      icon: Icons.monetization_on_rounded,
      label: 'Coins',
      amount: 1000,
    ),
  ],
  DateTime? expiresAt,
  VoidCallback? onOpen,
  VoidCallback? onClaim,
  DateTime Function()? clock,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: InboxMessageCard(
          title: title,
          body: body,
          receivedLabel: receivedLabel,
          isRead: isRead,
          isClaimed: isClaimed,
          attachments: attachments,
          expiresAt: expiresAt,
          onOpen: onOpen,
          onClaim: onClaim,
          clock: clock,
        ),
      ),
    ),
  ),
);

void main() {
  group('InboxMessageCard validation', () {
    test('rejects empty title, body, claimLabel or negative amount', () {
      expect(
        () => InboxMessageCard(title: ' ', body: 'text'),
        throwsArgumentError,
      );
      expect(
        () => InboxMessageCard(title: 'Title', body: ' '),
        throwsArgumentError,
      );
      expect(
        () => InboxMessageCard(title: 'Title', body: 'Body', claimLabel: ''),
        throwsArgumentError,
      );
      expect(
        () => InboxMessageCard(
          title: 'Title',
          body: 'Body',
          attachments: const [
            InboxAttachment(icon: Icons.star, label: 'Stars', amount: -1),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('InboxMessageCard UI', () {
    testWidgets('shows unread badge when unread, hides when read', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(isRead: false));
      expect(find.byKey(const ValueKey('inboxUnreadBadge')), findsOneWidget);

      await tester.pumpWidget(_subject(isRead: true));
      expect(find.byKey(const ValueKey('inboxUnreadBadge')), findsNothing);
    });

    testWidgets('tapping card triggers onOpen', (tester) async {
      var opened = false;
      await tester.pumpWidget(_subject(onOpen: () => opened = true));

      await tester.tap(find.byKey(const ValueKey('inboxMessageCardTap')));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('tapping claim triggers onClaim', (tester) async {
      var claimed = false;
      await tester.pumpWidget(_subject(onClaim: () => claimed = true));

      await tester.tap(find.byKey(const ValueKey('inboxClaimBtn')));
      await tester.pump();
      expect(claimed, isTrue);
    });

    testWidgets('claimed state disables button and shows Claimed', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(isClaimed: true, onClaim: () {}));
      final btn = tester.widget<CommonButton>(
        find.byKey(const ValueKey('inboxClaimBtn')),
      );
      expect(btn.label, 'Claimed');
      expect(btn.onTap, isNull);
    });

    testWidgets('expired disables button and shows Expired', (tester) async {
      final now = DateTime(2026, 10, 18, 12, 0);
      await tester.pumpWidget(
        _subject(
          expiresAt: now.subtract(const Duration(minutes: 5)),
          onClaim: () {},
          clock: () => now,
        ),
      );

      expect(find.text('Expired'), findsOneWidget);
      final btn = tester.widget<CommonButton>(
        find.byKey(const ValueKey('inboxClaimBtn')),
      );
      expect(btn.onTap, isNull);
    });

    testWidgets('timer ticks and flips to expired on deadline', (tester) async {
      var now = DateTime(2026, 10, 18, 12, 0, 0);
      final expiry = DateTime(2026, 10, 18, 12, 0, 2);

      await tester.pumpWidget(
        _subject(expiresAt: expiry, clock: () => now, onClaim: () {}),
      );

      expect(find.text('Expires in 00:02'), findsOneWidget);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Expired'), findsOneWidget);
      final btn = tester.widget<CommonButton>(
        find.byKey(const ValueKey('inboxClaimBtn')),
      );
      expect(btn.onTap, isNull);
    });

    testWidgets('semantics reads unread status, attachments and expiry', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 18, 12, 0);
      await tester.pumpWidget(
        _subject(
          isRead: false,
          expiresAt: now.add(const Duration(days: 2, hours: 3)),
          clock: () => now,
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('inboxMessageCardSemantics')),
      );
      expect(semantics.properties.label, contains('Unread'));
      expect(semantics.properties.label, contains('2 attachments'));
      expect(semantics.properties.label, contains('Expires in 2d 3h'));
    });

    testWidgets('unmount cancels timer cleanly without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(expiresAt: DateTime.now().add(const Duration(minutes: 30))),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
