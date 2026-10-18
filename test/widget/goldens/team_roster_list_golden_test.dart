import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/team_roster_list.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

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

void main() {
  final previousGoldenComparator = installGoldenTolerance(
    'team_roster_list_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('TeamRosterList roles and actions qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: TeamRosterList(
          members: _members,
          maxMembers: 50,
          onMemberTap: (_) {},
          onPromote: (_) {},
          onKick: (_) {},
        ),
      ),
      goldenBaseName: 'team_roster_list',
    );
  });

  testWidgets('TeamRosterList empty qua Golden Matrix', (tester) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: TeamRosterList(members: const [], onMemberTap: (_) {}),
      ),
      goldenBaseName: 'team_roster_list_empty',
    );
  });
}
