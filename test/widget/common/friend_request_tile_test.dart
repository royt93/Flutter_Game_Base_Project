import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget subject({
  FriendRequestAction? busy,
  ValueChanged<String>? accept,
  ValueChanged<String>? decline,
  double scale = 1,
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reducedMotion,
    ),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FriendRequestTile(
            request: FriendRequestItem(
              requestId: 'r1',
              name: 'Maya Rose',
              subtitle: 'Level 42',
              mutualFriendsCount: 3,
              avatar: const Icon(Icons.face),
            ),
            busyAction: busy,
            onAccept: accept ?? (_) {},
            onDecline: decline ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('haptics respect preference and never fire while busy', (
    tester,
  ) async {
    final storage = Get.put(StorageService(null));
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      Get.reset();
    });
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('friendRequest_accept_r1')));
    await tester.pump();
    expect(calls, ['HapticFeedbackType.lightImpact']);
    await storage.setBool(StorageKeys.hapticsEnabled, false);
    await tester.tap(find.byKey(const ValueKey('friendRequest_decline_r1')));
    await tester.pump();
    expect(calls, hasLength(1));
    await storage.setBool(StorageKeys.hapticsEnabled, true);
    await tester.pumpWidget(subject(busy: FriendRequestAction.accept));
    await tester.tap(find.byKey(const ValueKey('friendRequest_accept_r1')));
    await tester.pump();
    expect(calls, hasLength(1));
  });

  test('validates request identity, count and labels at runtime', () {
    expect(
      () => FriendRequestItem(requestId: ' ', name: 'Maya'),
      throwsArgumentError,
    );
    expect(
      () => FriendRequestItem(requestId: 'r', name: ' '),
      throwsArgumentError,
    );
    expect(
      () => FriendRequestItem(
        requestId: 'r',
        name: 'Maya',
        mutualFriendsCount: -1,
      ),
      throwsArgumentError,
    );
    for (final accept in [true, false]) {
      expect(
        () => FriendRequestTile(
          request: FriendRequestItem(requestId: 'r', name: 'Maya'),
          onAccept: (_) {},
          onDecline: (_) {},
          acceptLabel: accept ? ' ' : 'Accept',
          declineLabel: accept ? 'Decline' : ' ',
        ),
        throwsArgumentError,
      );
    }
  });

  testWidgets('renders identity, subtitle, avatar and mutual friends', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    expect(find.text('Maya Rose'), findsOneWidget);
    expect(find.text('Level 42'), findsOneWidget);
    expect(find.text('3 mutual friends'), findsOneWidget);
    expect(find.byIcon(Icons.face), findsOneWidget);
  });

  testWidgets('routes both callbacks with request ID', (tester) async {
    final accepted = <String>[];
    final declined = <String>[];
    await tester.pumpWidget(
      subject(accept: accepted.add, decline: declined.add),
    );
    await tester.tap(find.byKey(const ValueKey('friendRequest_accept_r1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('friendRequest_decline_r1')));
    expect(accepted, ['r1']);
    expect(declined, ['r1']);
  });

  testWidgets('busy identifies active action and blocks both callbacks', (
    tester,
  ) async {
    var calls = 0;
    for (final action in FriendRequestAction.values) {
      await tester.pumpWidget(
        subject(busy: action, accept: (_) => calls++, decline: (_) => calls++),
      );
      final buttons = tester
          .widgetList<CommonButton>(find.byType(CommonButton))
          .toList();
      expect(buttons[0].loading, action == FriendRequestAction.accept);
      expect(buttons[1].loading, action == FriendRequestAction.decline);
      await tester.tap(find.byKey(const ValueKey('friendRequest_accept_r1')));
      await tester.tap(find.byKey(const ValueKey('friendRequest_decline_r1')));
      expect(calls, 0);
    }
    await tester.pumpWidget(subject(accept: (_) => calls++));
    await tester.tap(find.byKey(const ValueKey('friendRequest_accept_r1')));
    expect(calls, 1);
  });

  testWidgets('320dp at 2x text stacks actions with 48dp targets in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(scale: 2, direction: TextDirection.rtl));
    final accept = find.byKey(const ValueKey('friendRequest_accept_r1'));
    final decline = find.byKey(const ValueKey('friendRequest_decline_r1'));
    for (final target in [accept, decline]) {
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }
    expect(
      tester.getTopLeft(decline).dy,
      greaterThan(tester.getBottomLeft(accept).dy),
    );
    expect(Directionality.of(tester.element(accept)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes enabled and busy action semantics', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject());
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('friendRequest_accept_r1')),
        ),
        matchesSemantics(
          label: 'Accept Maya Rose',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.pumpWidget(subject(busy: FriendRequestAction.decline));
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('friendRequest_decline_r1')),
        ),
        matchesSemantics(
          label: 'Decline Maya Rose, loading',
          isButton: true,
          hasEnabledState: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'formats zero and singular mutual friends and accepts caller copy',
    (tester) async {
      for (final count in [0, 1, 200]) {
        await tester.pumpWidget(
          MaterialApp(
            home: FriendRequestTile(
              request: FriendRequestItem(
                requestId: 'r',
                name: 'Maya',
                mutualFriendsCount: count,
              ),
              onAccept: (_) {},
              onDecline: (_) {},
            ),
          ),
        );
        expect(
          find.text('$count mutual ${count == 1 ? 'friend' : 'friends'}'),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestTile(
            request: FriendRequestItem(requestId: 'r', name: 'Maya'),
            onAccept: (_) {},
            onDecline: (_) {},
            mutualFriendsText: 'Không có bạn chung',
            acceptLabel: 'Chấp nhận',
            declineLabel: 'Từ chối',
          ),
        ),
      );
      expect(find.text('Không có bạn chung'), findsOneWidget);
    },
  );

  testWidgets(
    'press bounce stops with reduced motion and unmount disposes busy ticker',
    (tester) async {
      await tester.pumpWidget(subject(reducedMotion: true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('friendRequest_accept_r1'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
      await gesture.up();
      await tester.pumpWidget(subject(busy: FriendRequestAction.accept));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
