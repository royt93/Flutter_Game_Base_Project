import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _milestones = [
  FriendInviteMilestone(
    id: 'invite_1',
    requiredInvites: 1,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x20',
    ),
  ),
  FriendInviteMilestone(
    id: 'invite_3',
    requiredInvites: 3,
    reward: MilestoneReward(
      icon: Icons.shield_rounded,
      label: 'Shield',
      amountLabel: 'x1',
    ),
  ),
];

Widget _subject({
  int completed = 1,
  int goal = 3,
  List<FriendInviteMilestone> milestones = const [],
  String? inviteCode,
  VoidCallback? onInvite,
  VoidCallback? onCopyInvite,
  ValueChanged<String>? onClaimReward,
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
      child: SingleChildScrollView(
        child: FriendInviteProgressCard(
          completedInvites: completed,
          inviteGoal: goal,
          milestones: milestones,
          inviteCode: inviteCode,
          onInvite: onInvite ?? () {},
          onCopyInvite: onCopyInvite,
          onClaimReward: onClaimReward ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  group('FriendInviteProgressCard validation', () {
    test(
      'rejects negative invite count, non-positive goal and duplicate IDs',
      () {
        expect(
          () => FriendInviteProgressCard(
            completedInvites: -1,
            inviteGoal: 3,
            milestones: const [],
            onInvite: () {},
            onClaimReward: (_) {},
          ),
          throwsArgumentError,
        );
        expect(
          () => FriendInviteProgressCard(
            completedInvites: 0,
            inviteGoal: 0,
            milestones: const [],
            onInvite: () {},
            onClaimReward: (_) {},
          ),
          throwsArgumentError,
        );
        expect(
          () => FriendInviteProgressCard(
            completedInvites: 0,
            inviteGoal: 3,
            milestones: [
              _milestones.first,
              FriendInviteMilestone(
                id: 'invite_1',
                requiredInvites: 2,
                reward: _milestones.last.reward,
              ),
            ],
            onInvite: () {},
            onClaimReward: (_) {},
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('FriendInviteProgressCard UI', () {
    testWidgets('shows progress and caller-owned invite/copy callbacks', (
      tester,
    ) async {
      var invites = 0;
      var copied = 0;
      await tester.pumpWidget(
        _subject(
          completed: 1,
          goal: 3,
          inviteCode: 'ABC123',
          onInvite: () => invites++,
          onCopyInvite: () => copied++,
        ),
      );
      expect(find.text('1 / 3 invited'), findsOneWidget);
      expect(find.text('Code: ABC123'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('friendInviteActionBtn')));
      await tester.tap(find.byKey(const ValueKey('friendInviteCopyBtn')));
      expect(invites, 1);
      expect(copied, 1);
    });

    testWidgets('milestones lock and claim using exact milestone id', (
      tester,
    ) async {
      final claimed = <String>[];
      await tester.pumpWidget(
        _subject(
          completed: 1,
          milestones: _milestones,
          onClaimReward: claimed.add,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('friendInviteMilestone_invite_1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('friendInviteMilestone_invite_3')),
      );
      expect(claimed, ['invite_1']);
    });

    testWidgets('clamps progress and announces state', (tester) async {
      await tester.pumpWidget(
        _subject(completed: 5, goal: 3, milestones: _milestones),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('friendInviteProgressSemantics')),
      );
      expect(
        semantics.properties.label,
        'Invite Friends. 5 of 3 invites completed. 2 reward milestones.',
      );
    });

    testWidgets('no overflow at text scale 2.0', (tester) async {
      await tester.pumpWidget(_subject(textScale2: true));
      expect(tester.takeException(), isNull);
    });
  });
}
