import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _events = [
  EventCalendarItem(
    id: 'boss',
    dayLabel: 'MON',
    title: 'Weekly Boss',
    timeLabel: '10:00–18:00',
    status: EventCalendarStatus.active,
    icon: Icons.bolt_rounded,
  ),
  EventCalendarItem(
    id: 'tournament',
    dayLabel: 'WED',
    title: 'Puzzle Tournament',
    timeLabel: 'Starts 12:00',
    status: EventCalendarStatus.upcoming,
  ),
  EventCalendarItem(
    id: 'flashback',
    dayLabel: 'SUN',
    title: 'Flashback Challenge',
    timeLabel: 'Ended 20:00',
    status: EventCalendarStatus.ended,
  ),
];

Widget _subject({
  List<EventCalendarItem> events = _events,
  ValueChanged<String>? onOpen,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: EventCalendarCard(events: events, onOpen: onOpen ?? (_) {}),
      ),
    ),
  ),
);

void main() {
  group('EventCalendarCard validation', () {
    test('rejects empty required fields and duplicate ids', () {
      expect(
        () => EventCalendarCard(
          events: const [
            EventCalendarItem(
              id: 'duplicate',
              dayLabel: 'MON',
              title: 'One',
              timeLabel: '10:00',
              status: EventCalendarStatus.active,
            ),
            EventCalendarItem(
              id: 'duplicate',
              dayLabel: 'TUE',
              title: 'Two',
              timeLabel: '11:00',
              status: EventCalendarStatus.upcoming,
            ),
          ],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => EventCalendarCard(
          events: const [
            EventCalendarItem(
              id: ' ',
              dayLabel: 'MON',
              title: 'Event',
              timeLabel: '10:00',
              status: EventCalendarStatus.active,
            ),
          ],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => EventCalendarCard(
          events: const [
            EventCalendarItem(
              id: 'event',
              dayLabel: 'MON',
              title: ' ',
              timeLabel: '10:00',
              status: EventCalendarStatus.active,
            ),
          ],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => EventCalendarCard(events: _events, onOpen: (_) {}, title: ' '),
        throwsArgumentError,
      );
    });
  });

  group('EventCalendarCard UI', () {
    testWidgets('shows states in caller order and opens active/upcoming only', (
      tester,
    ) async {
      final opened = <String>[];
      await tester.pumpWidget(_subject(onOpen: opened.add));

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('eventCalendar_boss'))).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('eventCalendar_tournament')),
              )
              .dy,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('eventCalendarOpen_boss')));
      await tester.tap(
        find.byKey(const ValueKey('eventCalendarOpen_tournament')),
      );
      expect(opened, ['boss', 'tournament']);
      expect(
        find.byKey(const ValueKey('eventCalendarOpen_flashback')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows empty state and semantics count', (tester) async {
      await tester.pumpWidget(_subject(events: const []));
      expect(find.text('No events scheduled.'), findsOneWidget);

      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('eventCalendarSemantics')),
      );
      expect(semantics.properties.label, 'Event Calendar. 3 events.');
    });

    testWidgets('no overflow at text scale 2.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(_subject());
      expect(tester.takeException(), isNull);
    });
  });
}
