import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/consumer_contract_test_kit.dart';
import 'package:roy_casual_kit/core/kit_bootstrap.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await RoyCasualKit.resetForTesting();
    Get.reset();
  });

  test('fixture is deterministic and contract report passes', () async {
    final fixture = RoyCasualKitTestFixture();
    final report = await RoyCasualKitContractTestKit.verifyBootstrap(
      initialize: () => RoyCasualKit.initialize(config: fixture.config),
      expectedModules: fixture.modules,
    );

    expect(report.passed, isTrue);
    expect(report.failures, isEmpty);
    expect(StorageService.maybe, same(fixture.storage));
  });

  test('report identifies missing modules without throwing', () async {
    final fixture = RoyCasualKitTestFixture(
      modules: const {RoyCasualKitModule.storage},
    );
    final report = await RoyCasualKitContractTestKit.verifyBootstrap(
      initialize: () => RoyCasualKit.initialize(config: fixture.config),
      expectedModules: RoyCasualKitModule.values.toSet(),
    );

    expect(report.passed, isFalse);
    expect(report.failures, contains('all expected modules registered'));
  });

  testWidgets('consumer can render a contract result in a widget', (
    tester,
  ) async {
    final fixture = RoyCasualKitTestFixture();
    final report = await RoyCasualKitContractTestKit.verifyBootstrap(
      initialize: () => RoyCasualKit.initialize(config: fixture.config),
      expectedModules: fixture.modules,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Text(report.passed ? 'contract-ok' : 'contract-failed'),
      ),
    );
    expect(find.text('contract-ok'), findsOneWidget);
  });
}
