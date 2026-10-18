import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/gift_lives_request_card.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previousGoldenComparator = installGoldenTolerance(
    'gift_lives_request_card_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('GiftLivesRequestCard pending state qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GiftLivesRequestCard(
            request: const GiftLivesRequest(
              requestId: 'req_1',
              senderName: 'Maya Rose',
              requestedAtText: '12m ago',
              state: GiftLivesRequestState.pending,
            ),
            statusText: 'Expires in 2h',
            onSendLife: (_) {},
          ),
        ),
      ),
      goldenBaseName: 'gift_lives_request_card_pending',
    );
  });

  testWidgets('GiftLivesRequestCard sent state qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GiftLivesRequestCard(
            request: const GiftLivesRequest(
              requestId: 'req_2',
              senderName: 'Liam Chen',
              requestedAtText: '1h ago',
              state: GiftLivesRequestState.sent,
            ),
            statusText: 'Sent today',
            onSendLife: (_) {},
          ),
        ),
      ),
      goldenBaseName: 'gift_lives_request_card_sent',
    );
  });

  testWidgets('GiftLivesRequestCard expired state qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GiftLivesRequestCard(
            request: const GiftLivesRequest(
              requestId: 'req_3',
              senderName: 'Zoe Vance',
              requestedAtText: '1d ago',
              state: GiftLivesRequestState.expired,
            ),
            statusText: 'Expired',
            onSendLife: (_) {},
          ),
        ),
      ),
      goldenBaseName: 'gift_lives_request_card_expired',
    );
  });
}
