import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/booster_slot_bar.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('BoosterSlot validation & state', () {
    test('rejects empty id or label', () {
      expect(() => BoosterSlot(id: '', label: 'Hammer'), throwsArgumentError);
      expect(() => BoosterSlot(id: 'h1', label: '   '), throwsArgumentError);
    });

    test('rejects negative count or cooldown', () {
      expect(
        () => BoosterSlot(id: 'h1', label: 'Hammer', count: -1),
        throwsArgumentError,
      );
      expect(
        () => BoosterSlot(
          id: 'h1',
          label: 'Hammer',
          cooldown: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('state getters correctly identify ready, empty, and cooldown', () {
      final ready = BoosterSlot(id: '1', label: 'Hammer', count: 3);
      expect(ready.isReady, isTrue);
      expect(ready.isEmpty, isFalse);
      expect(ready.isCoolingDown, isFalse);

      final empty = BoosterSlot(id: '2', label: 'Bomb', count: 0);
      expect(empty.isReady, isFalse);
      expect(empty.isEmpty, isTrue);
      expect(empty.isCoolingDown, isFalse);

      final cooling = BoosterSlot(
        id: '3',
        label: 'Shuffle',
        count: 2,
        cooldown: const Duration(seconds: 15),
      );
      expect(cooling.isReady, isFalse);
      expect(cooling.isEmpty, isFalse);
      expect(cooling.isCoolingDown, isTrue);

      final locked = BoosterSlot(id: '4', label: 'Laser', isLocked: true);
      expect(locked.isReady, isFalse);
      expect(locked.isEmpty, isFalse);
      expect(locked.isCoolingDown, isFalse);
    });
  });

  group('BoosterSlotBar validation', () {
    test('rejects empty or more than 5 slots', () {
      expect(() => BoosterSlotBar(slots: const []), throwsArgumentError);
      expect(
        () => BoosterSlotBar(
          slots: [
            for (var i = 0; i < 6; i++)
              BoosterSlot(id: 'b$i', label: 'Booster $i'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate slot IDs', () {
      expect(
        () => BoosterSlotBar(
          slots: [
            BoosterSlot(id: 'dup', label: 'First'),
            BoosterSlot(id: 'dup', label: 'Second'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive slotSize or negative spacing', () {
      expect(
        () => BoosterSlotBar(
          slots: [BoosterSlot(id: '1', label: 'B')],
          slotSize: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => BoosterSlotBar(
          slots: [BoosterSlot(id: '1', label: 'B')],
          spacing: -2,
        ),
        throwsArgumentError,
      );
    });
  });

  group('BoosterSlotBar interactions and lifecycle', () {
    testWidgets('ready slot displays count and calls onSlotTap', (
      tester,
    ) async {
      String? tappedId;
      await tester.pumpWidget(
        _wrap(
          BoosterSlotBar(
            slots: [BoosterSlot(id: 'hammer', label: 'Hammer', count: 3)],
            onSlotTap: (id) => tappedId = id,
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('boosterSlotTap_hammer')));
      expect(tappedId, 'hammer');
    });

    testWidgets('empty slot displays (+) badge and calls onEmptySlotTap', (
      tester,
    ) async {
      String? emptyTappedId;
      await tester.pumpWidget(
        _wrap(
          BoosterSlotBar(
            slots: [BoosterSlot(id: 'bomb', label: 'Bomb', count: 0)],
            onEmptySlotTap: (id) => emptyTappedId = id,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('boosterSlotEmptyBadge_bomb')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('boosterSlotTap_bomb')));
      expect(emptyTappedId, 'bomb');
    });

    testWidgets('locked slot displays lock icon and disables tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BoosterSlotBar(
            slots: [
              BoosterSlot(
                id: 'laser',
                label: 'Laser',
                count: 5,
                isLocked: true,
              ),
            ],
            onSlotTap: (_) => taps++,
            onEmptySlotTap: (_) => taps++,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('boosterSlotLock_laser')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('boosterSlotTap_laser')));
      expect(taps, 0);
    });

    testWidgets(
      'cooldown ticks, blocks tap, and transitions to ready when done',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _wrap(
            BoosterSlotBar(
              slots: [
                BoosterSlot(
                  id: 'shuffle',
                  label: 'Shuffle',
                  count: 2,
                  cooldown: const Duration(seconds: 2),
                ),
              ],
              onSlotTap: (_) => taps++,
            ),
          ),
        );

        // In cooldown: text shows 2s and tap does nothing
        expect(find.text('2s'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('boosterSlotTap_shuffle')));
        expect(taps, 0);

        // Advance 1 second: text updates to 1s
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1s'), findsOneWidget);
        expect(taps, 0);

        // Advance past zero: cooldown overlay disappears, slot becomes ready
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byKey(const ValueKey('boosterSlotCooldown_shuffle')),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('boosterSlotTap_shuffle')));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'count increase triggers badge animation, skipped in Reduced Motion',
      (tester) async {
        Widget build(int count, {bool reduced = false}) => _wrap(
          BoosterSlotBar(
            slots: [BoosterSlot(id: 'boost', label: 'Booster', count: count)],
          ),
          reduced: reduced,
        );

        await tester.pumpWidget(build(1));
        expect(find.text('1'), findsOneWidget);

        await tester.pumpWidget(build(2));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('2'), findsOneWidget);

        await tester.pumpWidget(build(3, reduced: true));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('semantics accurately describe slot states', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          BoosterSlotBar(
            slots: [
              BoosterSlot(id: 'h', label: 'Hammer', count: 3),
              BoosterSlot(id: 'b', label: 'Bomb', count: 0),
              BoosterSlot(id: 'l', label: 'Laser', isLocked: true),
            ],
          ),
        ),
      );

      final hammer = tester.getSemantics(
        find.byKey(const ValueKey('boosterSlotTap_h')),
      );
      expect(hammer.label, 'Hammer, 3 available');

      final bomb = tester.getSemantics(
        find.byKey(const ValueKey('boosterSlotTap_b')),
      );
      expect(bomb.label, 'Bomb, empty, tap to add');

      final laser = tester.getSemantics(
        find.byKey(const ValueKey('boosterSlotTap_l')),
      );
      expect(laser.label, 'Laser, locked');

      handle.dispose();
    });
  });
}
