import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/save_migration_registry.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  SaveMigrationStep step(int from, int to, String key) => SaveMigrationStep(
    fromVersion: from,
    toVersion: to,
    migrate: (input) => {...input, key: true},
  );

  test('runs multi-hop in order without mutating input', () {
    final registry = SaveMigrationRegistry(
      currentVersion: 3,
      steps: [step(1, 2, 'v2'), step(2, 3, 'v3')],
    );
    final input = <String, Object?>{'schemaVersion': 1};
    final output = registry.migrate(1, input);
    expect(output['v2'], true);
    expect(output['v3'], true);
    expect(input, {'schemaVersion': 1});
  });

  test('rejects duplicate, backwards, future and missing steps', () {
    expect(
      () => SaveMigrationRegistry(
        currentVersion: 2,
        steps: [step(1, 2, 'a'), step(1, 2, 'b')],
      ),
      throwsA(isA<SaveMigrationException>()),
    );
    expect(
      () => SaveMigrationRegistry(currentVersion: 2, steps: [step(2, 1, 'a')]),
      throwsA(isA<SaveMigrationException>()),
    );
    expect(
      () => SaveMigrationRegistry(currentVersion: 2, steps: [step(1, 3, 'a')]),
      throwsA(isA<SaveMigrationException>()),
    );
    final missing = SaveMigrationRegistry(
      currentVersion: 3,
      steps: [step(1, 2, 'a')],
    );
    expect(
      () => missing.migrate(1, {}),
      throwsA(isA<SaveMigrationException>()),
    );
  });

  test('failed step leaves caller input and registry reusable', () {
    var calls = 0;
    final registry = SaveMigrationRegistry(
      currentVersion: 2,
      steps: [
        SaveMigrationStep(
          fromVersion: 1,
          toVersion: 2,
          migrate: (input) {
            calls++;
            throw StateError('bad');
          },
        ),
      ],
    );
    final input = <String, Object?>{'x': 1};
    expect(() => registry.migrate(1, input), throwsStateError);
    expect(input, {'x': 1});
    expect(calls, 1);
  });

  testWidgets('migration status can be presented by a consumer widget', (
    tester,
  ) async {
    final registry = SaveMigrationRegistry(
      currentVersion: 2,
      steps: [step(1, 2, 'migrated')],
    );
    final migrated = registry.migrate(1, {})['migrated'] == true;
    await tester.pumpWidget(
      MaterialApp(
        home: CommonButton(
          label: migrated ? 'Migrated' : 'Failed',
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Migrated').evaluate(), isNotEmpty);
  });
}
