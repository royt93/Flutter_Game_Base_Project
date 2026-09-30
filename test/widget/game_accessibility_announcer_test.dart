import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/game_accessibility_announcer.dart';
import 'package:roy_casual_kit/core/game_event_bus.dart';

/// Small host exercising [GameAccessibilityAnnouncer] wired into a real
/// widget lifecycle — same shape a consumer app's game screen would use:
/// own the bus + announcer in [State], dispose in [State.dispose], forward
/// gameplay events from button taps (standing in for game logic).
class _AnnouncerHost extends StatefulWidget {
  const _AnnouncerHost({required this.locale, this.enabled = true});

  final Locale locale;
  final bool enabled;

  @override
  State<_AnnouncerHost> createState() => _AnnouncerHostState();
}

class _AnnouncerHostState extends State<_AnnouncerHost> {
  late final GameEventBus _bus;
  late final GameAccessibilityAnnouncer _announcer;
  final List<String> spoken = [];
  var _nowMs = 0;

  @override
  void initState() {
    super.initState();
    _bus = GameEventBus();
    _announcer = GameAccessibilityAnnouncer(
      eventBus: _bus,
      announce: (message) async => setState(() => spoken.add(message)),
      locale: () => widget.locale,
      isEnabled: () => widget.enabled,
      nowMs: () => _nowMs,
      throttleWindow: const Duration(milliseconds: 500),
    );
  }

  void advanceClock(int ms) => _nowMs += ms;

  @override
  void dispose() {
    unawaited(_announcer.dispose());
    unawaited(_bus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('spoken: ${spoken.join('|')}'),
      ElevatedButton(
        onPressed: () => _bus.emit(
          GameAccessibilityEvent(
            category: GameAccessibilityCategory.levelUp,
            translationKey: 'a11y_level_up',
            parameters: const {'value': '5'},
          ),
        ),
        child: const Text('level up'),
      ),
      ElevatedButton(
        onPressed: () => _bus.emit(
          GameAccessibilityEvent(
            category: GameAccessibilityCategory.reward,
            translationKey: 'a11y_reward_granted',
            parameters: const {'value': '10 gems'},
          ),
        ),
        child: const Text('reward'),
      ),
    ],
  );
}

void main() {
  testWidgets('locale en: tap level up hiện đúng text đã dịch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _AnnouncerHost(locale: const Locale('en'))),
    );

    await tester.tap(find.text('level up'));
    await tester.pump();

    expect(find.text('spoken: Level up! Now level 5.'), findsOneWidget);
  });

  testWidgets('locale vi: tap reward hiện đúng text đã dịch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _AnnouncerHost(locale: const Locale('vi'))),
    );

    await tester.tap(find.text('reward'));
    await tester.pump();

    expect(find.text('spoken: Nhận thưởng: 10 gems.'), findsOneWidget);
  });

  testWidgets(
    'burst: 2 tap level up liên tiếp trong cửa sổ chỉ announce 1 lần',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: _AnnouncerHost(locale: const Locale('en'))),
      );

      await tester.tap(find.text('level up'));
      await tester.pump();
      await tester.tap(find.text('level up'));
      await tester.pump();

      expect(find.text('spoken: Level up! Now level 5.'), findsOneWidget);
    },
  );

  testWidgets('disabled=false -> tap không announce gì', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _AnnouncerHost(locale: const Locale('en'), enabled: false),
      ),
    );

    await tester.tap(find.text('reward'));
    await tester.pump();

    expect(find.text('spoken: '), findsOneWidget);
  });

  testWidgets(
    'dispose host (unmount) không throw dù có event vừa emit trước đó',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: _AnnouncerHost(locale: const Locale('en'))),
      );
      await tester.tap(find.text('level up'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
