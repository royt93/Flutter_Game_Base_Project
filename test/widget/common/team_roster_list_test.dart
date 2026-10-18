import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _members = [
  TeamMemberItem(
    id: 'ana',
    name: 'Ana',
    role: TeamRole.leader,
    trophies: 4200,
    isOnline: true,
  ),
  TeamMemberItem(
    id: 'bao',
    name: 'Bao Nguyen',
    role: TeamRole.elder,
    trophies: 1800,
    lastSeenText: '5m ago',
  ),
  TeamMemberItem(
    id: 'cy',
    name: 'Cy',
    role: TeamRole.member,
    trophies: 300,
    isSelf: true,
  ),
];

Widget _subject({
  List<TeamMemberItem> members = _members,
  ValueChanged<String>? onTap,
  ValueChanged<String>? onPromote,
  ValueChanged<String>? onKick,
  int? maxMembers,
  bool textScale2 = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale2 ? 2 : 1)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: TeamRosterList(
        members: members,
        onMemberTap: onTap ?? (_) {},
        onPromote: onPromote,
        onKick: onKick,
        maxMembers: maxMembers,
        maxListHeight: 320,
      ),
    ),
  ),
);

void main() {
  group('TeamRosterList validation', () {
    test('rejects bad ids, names, trophies, capacity and sizes', () {
      void invalid({
        List<TeamMemberItem> members = const [],
        int? maxMembers,
        double maxListHeight = 420,
        String title = 'T',
        String emptyMessage = 'E',
      }) => expect(
        () => TeamRosterList(
          members: members,
          onMemberTap: (_) {},
          maxMembers: maxMembers,
          maxListHeight: maxListHeight,
          title: title,
          emptyMessage: emptyMessage,
        ),
        throwsArgumentError,
      );

      const ok = TeamMemberItem(id: 'a', name: 'A', role: TeamRole.member);
      invalid(
        members: const [
          TeamMemberItem(id: ' ', name: 'A', role: TeamRole.member),
        ],
      );
      invalid(
        members: const [
          TeamMemberItem(id: 'a', name: ' ', role: TeamRole.member),
        ],
      );
      invalid(members: const [ok, ok]);
      invalid(
        members: const [
          TeamMemberItem(
            id: 'a',
            name: 'A',
            role: TeamRole.member,
            trophies: -1,
          ),
        ],
      );
      invalid(maxMembers: 0);
      invalid(members: const [ok], maxMembers: 0);
      invalid(
        members: const [
          ok,
          TeamMemberItem(id: 'b', name: 'B', role: TeamRole.member),
        ],
        maxMembers: 1,
      );
      invalid(maxListHeight: 0);
      invalid(maxListHeight: double.infinity);
      invalid(title: ' ');
      invalid(emptyMessage: ' ');
    });
  });

  group('TeamRosterList UI', () {
    testWidgets('shows roles, trophies, status and capacity', (tester) async {
      await tester.pumpWidget(_subject(maxMembers: 50));
      expect(find.text('3/50'), findsOneWidget);
      expect(find.text('LEADER'), findsOneWidget);
      expect(find.text('ELDER'), findsOneWidget);
      expect(find.text('MEMBER'), findsOneWidget);
      expect(find.text('4,200'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('5m ago'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('tap, promote and kick route member ids', (tester) async {
      final tapped = <String>[];
      final promoted = <String>[];
      final kicked = <String>[];
      await tester.pumpWidget(
        _subject(
          onTap: tapped.add,
          onPromote: promoted.add,
          onKick: kicked.add,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('teamMemberTile_bao')));
      await tester.tap(find.byKey(const ValueKey('teamMemberPromote_bao')));
      await tester.tap(find.byKey(const ValueKey('teamMemberKick_bao')));
      expect(tapped, ['bao']);
      expect(promoted, ['bao']);
      expect(kicked, ['bao']);
    });

    testWidgets('leader and self rows never expose promote or kick', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(onPromote: (_) {}, onKick: (_) {}));
      for (final id in ['ana', 'cy']) {
        expect(find.byKey(ValueKey('teamMemberPromote_$id')), findsNothing);
        expect(find.byKey(ValueKey('teamMemberKick_$id')), findsNothing);
      }
    });

    testWidgets('no action buttons when callbacks are null', (tester) async {
      await tester.pumpWidget(_subject());
      expect(find.byKey(const ValueKey('teamMemberKick_bao')), findsNothing);
      expect(find.byKey(const ValueKey('teamMemberPromote_bao')), findsNothing);
    });

    testWidgets('action targets are at least 48dp', (tester) async {
      await tester.pumpWidget(_subject(onPromote: (_) {}, onKick: (_) {}));
      for (final key in ['teamMemberPromote_bao', 'teamMemberKick_bao']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('long roster stays lazy and caps at maxListHeight', (
      tester,
    ) async {
      final members = List.generate(
        100,
        (i) => TeamMemberItem(
          id: 'm$i',
          name: 'Member $i',
          role: TeamRole.member,
          trophies: i,
        ),
      );
      await tester.pumpWidget(_subject(members: members));
      expect(find.byKey(const ValueKey('teamMemberTile_m99')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('teamRosterListView'))).height,
        320,
      );

      await tester.fling(
        find.byKey(const ValueKey('teamRosterListView')),
        const Offset(0, -300),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('short roster fits content height', (tester) async {
      await tester.pumpWidget(_subject());
      final height = tester
          .getSize(find.byKey(const ValueKey('teamRosterListView')))
          .height;
      expect(height, 3 * 68 + 2 * 8);
    });

    testWidgets('expand fills the bounded parent height instead of fitting', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: TeamRosterList(
                members: _members,
                onMemberTap: (_) {},
                expand: true,
              ),
            ),
          ),
        ),
      );
      final listHeight = tester
          .getSize(find.byKey(const ValueKey('teamRosterListView')))
          .height;
      final headerHeight = tester.getSize(find.text('Team Members')).height;
      expect(listHeight, greaterThan(3 * 68 + 2 * 8));
      expect(listHeight, lessThan(600));
      expect(listHeight + headerHeight, lessThanOrEqualTo(600));
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('teamRosterListView')))
            .dy,
        closeTo(600, 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand empty state centers message in remaining height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: TeamRosterList(
                members: const [],
                onMemberTap: (_) {},
                expand: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('No members in this team.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow 320dp at text scale 2.0 does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _subject(textScale2: true, onPromote: (_) {}, onKick: (_) {}),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state and semantics', (tester) async {
      await tester.pumpWidget(_subject(members: const []));
      expect(find.text('No members in this team.'), findsOneWidget);

      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('teamRosterSemantics')),
      );
      expect(semantics.properties.label, contains('3 members'));
      expect(semantics.properties.label, contains('1 online'));
    });
  });
}
