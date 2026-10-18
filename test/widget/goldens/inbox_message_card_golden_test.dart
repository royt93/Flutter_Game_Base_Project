import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/inbox_message_card.dart';

import '../../support/golden_matrix.dart';

final _now = DateTime(2026, 10, 18, 12);

const _attachments = [
  InboxAttachment(icon: Icons.diamond_rounded, label: 'Gems', amount: 50),
  InboxAttachment(
    icon: Icons.monetization_on_rounded,
    label: 'Coins',
    amount: 12000,
  ),
];

void main() {
  testWidgets('InboxMessageCard unread with expiry qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: InboxMessageCard(
          title: 'Weekend Event Reward',
          body: 'Thanks for playing! Collect your reward before it expires.',
          receivedLabel: '2 hours ago',
          attachments: _attachments,
          expiresAt: _now.add(const Duration(days: 2, hours: 5)),
          clock: () => _now,
          onOpen: () {},
          onClaim: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('InboxMessageCard read and claimed qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: InboxMessageCard(
          title: 'Welcome Gift',
          body: 'Starter pack.',
          isRead: true,
          isClaimed: true,
          attachments: _attachments,
          onClaim: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('InboxMessageCard expired qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: InboxMessageCard(
          title: 'Maintenance Compensation',
          body: 'Sorry for the downtime.',
          isRead: true,
          attachments: _attachments,
          expiresAt: _now.subtract(const Duration(hours: 1)),
          clock: () => _now,
          onClaim: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}
