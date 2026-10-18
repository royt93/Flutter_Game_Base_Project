import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/event_calendar_card.dart';

import '../../support/golden_matrix.dart';

const _events = [
  EventCalendarItem(
    id: 'active',
    dayLabel: 'MON',
    title: 'Weekly Boss',
    timeLabel: '10:00–18:00',
    status: EventCalendarStatus.active,
  ),
  EventCalendarItem(
    id: 'upcoming',
    dayLabel: 'WED',
    title: 'Puzzle Tournament',
    timeLabel: 'Starts 12:00',
    status: EventCalendarStatus.upcoming,
  ),
  EventCalendarItem(
    id: 'ended',
    dayLabel: 'SUN',
    title: 'Flashback Challenge',
    timeLabel: 'Ended 20:00',
    status: EventCalendarStatus.ended,
  ),
];

void main() {
  testWidgets('EventCalendarCard week schedule qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: EventCalendarCard(events: _events, onOpen: (_) {}),
      ),
      guidelines: const [],
    );
  });

  testWidgets('EventCalendarCard empty qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: EventCalendarCard(events: const [], onOpen: (_) {}),
      ),
      guidelines: const [],
    );
  });
}
