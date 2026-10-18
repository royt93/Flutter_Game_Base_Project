import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/friend_request_tile.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'friend_request_tile_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  for (final state in [
    'normal',
    'accept_busy',
    'decline_busy',
    'zero',
    'many',
  ]) {
    testWidgets('FriendRequestTile $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FriendRequestTile(
              request: FriendRequestItem(
                requestId: 'r',
                name: 'Maya Rose',
                subtitle: 'Level 42',
                mutualFriendsCount: state == 'zero'
                    ? 0
                    : state == 'many'
                    ? 250
                    : 3,
              ),
              busyAction: state == 'accept_busy'
                  ? FriendRequestAction.accept
                  : state == 'decline_busy'
                  ? FriendRequestAction.decline
                  : null,
              onAccept: (_) {},
              onDecline: (_) {},
            ),
          ),
        ),
        goldenBaseName: 'friend_request_tile_$state',
      );
    });
  }
}
