import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget _subject({
  GiftLivesRequest request = const GiftLivesRequest(
    requestId: 'r1',
    senderName: 'Maya',
    requestedAtText: '10m ago',
    state: GiftLivesRequestState.pending,
  ),
  ValueChanged<String>? onSend,
  Duration guardWindow = const Duration(milliseconds: 400),
  bool textScale2 = false,
  bool reducedMotion = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale2 ? 2 : 1),
      disableAnimations: reducedMotion,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: GiftLivesRequestCard(
          request: request,
          onSendLife: onSend ?? (_) {},
          guardWindow: guardWindow,
          statusText: 'Expires in 2h',
        ),
      ),
    ),
  ),
);

void main() {
  group('GiftLivesRequestCard validation', () {
    test('rejects empty id, senderName, labels and negative guardWindow', () {
      void invalid({
        GiftLivesRequest request = const GiftLivesRequest(
          requestId: 'r',
          senderName: 'S',
        ),
        String send = 'Send',
        String sent = 'Sent',
        String expired = 'Expired',
        Duration guard = Duration.zero,
      }) => expect(
        () => GiftLivesRequestCard(
          request: request,
          onSendLife: (_) {},
          sendLabel: send,
          sentLabel: sent,
          expiredLabel: expired,
          guardWindow: guard,
        ),
        throwsArgumentError,
      );

      invalid(
        request: const GiftLivesRequest(requestId: ' ', senderName: 'S'),
      );
      invalid(
        request: const GiftLivesRequest(requestId: 'r', senderName: ' '),
      );
      invalid(send: ' ');
      invalid(sent: ' ');
      invalid(expired: ' ');
      invalid(guard: const Duration(milliseconds: -1));
    });
  });

  group('GiftLivesRequestCard UI', () {
    testWidgets('shows pending state with action button', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_subject(onSend: sent.add));

      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Send Life'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.textContaining('10m ago · Expires in 2h'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r1')));
      expect(sent, ['r1']);
    });

    testWidgets('double-tap within guard window drops repeat calls', (
      tester,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _subject(
          onSend: sent.add,
          guardWindow: const Duration(milliseconds: 500),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r1')));
      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r1')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(sent, ['r1']);

      // After guard window expires, tap is allowed again.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r1')));
      expect(sent, ['r1', 'r1']);
    });

    testWidgets('sent state disables action and shows checkmark', (
      tester,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _subject(
          request: const GiftLivesRequest(
            requestId: 'r2',
            senderName: 'Liam',
            state: GiftLivesRequestState.sent,
          ),
          onSend: sent.add,
        ),
      );

      expect(find.text('Sent'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r2')));
      expect(sent, isEmpty);
    });

    testWidgets('expired state disables action and shows expired label', (
      tester,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _subject(
          request: const GiftLivesRequest(
            requestId: 'r3',
            senderName: 'Zoe',
            state: GiftLivesRequestState.expired,
          ),
          onSend: sent.add,
        ),
      );

      expect(find.text('Expired'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_disabled_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('giftLivesSend_r3')));
      expect(sent, isEmpty);
    });

    testWidgets('touch target is at least 48dp', (tester) async {
      await tester.pumpWidget(_subject());
      final buttonSize = tester.getSize(
        find.byKey(const ValueKey('giftLivesSend_r1')),
      );
      expect(buttonSize.width, greaterThanOrEqualTo(48));
      expect(buttonSize.height, greaterThanOrEqualTo(48));
    });

    testWidgets('narrow 320dp at text scale 2.0 does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_subject(textScale2: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion works cleanly', (tester) async {
      await tester.pumpWidget(_subject(reducedMotion: true));
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes accessible semantics for card and action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_subject());
        expect(
          find.bySemanticsLabel(RegExp(r'Maya asks for a life')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'Send Life to Maya')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('unmounts cleanly without leaking pending callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
