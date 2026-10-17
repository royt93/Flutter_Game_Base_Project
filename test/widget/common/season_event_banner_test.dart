import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/season_event_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/season_event_banner.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

void main() {
  group('SeasonEventBanner validation', () {
    test('rejects empty or whitespace title', () {
      expect(
        () => SeasonEventBanner(
          title: '',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: 0.5,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeasonEventBanner(
          title: '   ',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: 0.5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects progress outside 0..1 or non-finite', () {
      expect(
        () => SeasonEventBanner(
          title: 'Event',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeasonEventBanner(
          title: 'Event',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: 1.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeasonEventBanner(
          title: 'Event',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive height or width', () {
      expect(
        () => SeasonEventBanner(
          title: 'Event',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: 0.5,
          height: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeasonEventBanner(
          title: 'Event',
          endsAt: DateTime.now().add(const Duration(days: 1)),
          progress: 0.5,
          width: -10,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SeasonEventBanner rendering & lifecycle', () {
    testWidgets(
      'renders title, subtitle, milestone label, and multi-day countdown',
      (tester) async {
        final ends = DateTime.now().add(
          const Duration(days: 3, hours: 2, minutes: 30),
        );
        await tester.pumpWidget(
          _wrap(
            SeasonEventBanner(
              title: 'Spooky Season',
              subtitle: 'Collect Pumpkins for rewards',
              milestoneLabel: '15/30',
              endsAt: ends,
              progress: 0.5,
            ),
          ),
        );

        expect(find.text('Spooky Season'), findsOneWidget);
        expect(find.text('Collect Pumpkins for rewards'), findsOneWidget);
        expect(find.text('15/30'), findsOneWidget);
        expect(find.textContaining('3d 2h'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('named constructor fromWindow binds window.end', (
      tester,
    ) async {
      final windowEnd = DateTime.now().add(
        const Duration(hours: 5, minutes: 30),
      );
      final window = SeasonEventWindow(
        start: DateTime.now().subtract(const Duration(hours: 1)),
        end: windowEnd,
        isActive: true,
      );

      await tester.pumpWidget(
        _wrap(
          SeasonEventBanner.fromWindow(
            title: 'Tournament Cup',
            window: window,
            progress: 0.25,
          ),
        ),
      );

      expect(find.text('Tournament Cup'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('seasonEventCountdownText')),
        findsOneWidget,
      );
      expect(find.textContaining('05:'), findsOneWidget);
    });

    testWidgets('tap calls onTap when active and chevron is rendered', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          SeasonEventBanner(
            title: 'Live Event',
            endsAt: DateTime.now().add(const Duration(hours: 2)),
            progress: 0.4,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('seasonEventBannerTap')));
      expect(taps, 1);
    });

    testWidgets(
      'countdown ticks, expires, fires onEnded once and disables tap',
      (tester) async {
        var endedCalls = 0;
        var taps = 0;
        final target = DateTime.now().add(const Duration(seconds: 2));

        await tester.pumpWidget(
          _wrap(
            SeasonEventBanner(
              title: 'Flash Rush',
              endsAt: target,
              progress: 0.8,
              onTap: () => taps++,
              onEnded: () => endedCalls++,
            ),
          ),
        );

        expect(find.text('Ended'), findsNothing);

        // Advance clock past expiration
        await tester.pump(const Duration(seconds: 3));

        expect(endedCalls, 1);
        expect(find.text('Ended'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

        // Tapping banner after ended does nothing
        await tester.tap(find.byKey(const ValueKey('seasonEventBannerTap')));
        expect(taps, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pre-expired banner at mount fires onEnded deferred and renders Ended',
      (tester) async {
        var endedCalls = 0;
        await tester.pumpWidget(
          _wrap(
            SeasonEventBanner(
              title: 'Past Event',
              endsAt: DateTime.now().subtract(const Duration(minutes: 10)),
              progress: 1.0,
              onEnded: () => endedCalls++,
            ),
          ),
        );

        await tester.pump();
        expect(endedCalls, 1);
        expect(find.text('Ended'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Reduced Motion disables progress transition animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SeasonEventBanner(
            title: 'Winter Fest',
            endsAt: DateTime.now().add(const Duration(days: 2)),
            progress: 0.6,
          ),
          reduced: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Semantics announces title, countdown and milestone percent', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SeasonEventBanner(
            title: 'Halloween Hunt',
            endsAt: DateTime.now().add(
              const Duration(days: 4, hours: 6, minutes: 30),
            ),
            progress: 0.75,
            onTap: () {},
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(SeasonEventBanner));
      expect(node.label, contains('Halloween Hunt'));
      expect(node.label, contains('ends in 4d 6h'));
      expect(node.label, contains('75 percent milestone progress'));
      expect(node.value, '75%');
      handle.dispose();
    });
  });
}
