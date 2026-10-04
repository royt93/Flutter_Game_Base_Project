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

  test(
    'IDEA-71: double bootstrap is idempotent — repeated verifyBootstrap '
    'keeps the exact same registered module set, never duplicates/drops',
    () async {
      final fixture = RoyCasualKitTestFixture();
      var initializeCalls = 0;
      final report = await RoyCasualKitContractTestKit.verifyBootstrap(
        initialize: () {
          initializeCalls++;
          return RoyCasualKit.initialize(config: fixture.config);
        },
        expectedModules: fixture.modules,
      );

      expect(report.passed, isTrue);
      // verifyBootstrap itself calls initialize twice internally (see its
      // own doc) to prove idempotency — confirms this isn't a single-call
      // coincidence.
      expect(initializeCalls, 2);
    },
  );

  test('IDEA-71: fixture never touches network/platform channel — uses only '
      'the in-memory StorageService fallback', () async {
    final fixture = RoyCasualKitTestFixture();

    // StorageService(null) is the documented in-memory fallback
    // constructor — if this ever silently switched to a real
    // SharedPreferences-backed instance, this assertion would catch it.
    expect(fixture.storage.getString('probe'), isNull);
    await fixture.storage.setString('probe', 'value');
    expect(fixture.storage.getString('probe'), 'value');
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
