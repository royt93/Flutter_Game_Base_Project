import 'dart:convert';

class SaveMigrationStep {
  const SaveMigrationStep({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  });
  final int fromVersion;
  final int toVersion;
  final Map<String, Object?> Function(Map<String, Object?> input) migrate;
}

class SaveMigrationException implements Exception {
  const SaveMigrationException(this.message);
  final String message;
  @override
  String toString() => 'SaveMigrationException: $message';
}

/// Immutable, validated multi-hop save migration registry.
class SaveMigrationRegistry {
  SaveMigrationRegistry({
    required this.currentVersion,
    required List<SaveMigrationStep> steps,
  }) : steps = List.unmodifiable(steps) {
    if (currentVersion < 0) {
      throw const SaveMigrationException('currentVersion must be non-negative');
    }
    final seen = <int>{};
    for (final step in this.steps) {
      if (step.toVersion <= step.fromVersion) {
        throw const SaveMigrationException(
          'migration steps must increase version',
        );
      }
      if (step.toVersion > currentVersion) {
        throw SaveMigrationException(
          'step targets future version ${step.toVersion}',
        );
      }
      if (!seen.add(step.fromVersion)) {
        throw SaveMigrationException(
          'duplicate migration from ${step.fromVersion}',
        );
      }
    }
  }

  final int currentVersion;
  final List<SaveMigrationStep> steps;

  Map<String, Object?> migrate(int fromVersion, Map<String, Object?> input) {
    if (fromVersion > currentVersion) {
      throw const SaveMigrationException('save is from a future version');
    }
    var version = fromVersion;
    var output = _copy(input);
    while (version < currentVersion) {
      SaveMigrationStep? step;
      for (final candidate in steps) {
        if (candidate.fromVersion == version) {
          step = candidate;
          break;
        }
      }
      if (step == null) {
        throw SaveMigrationException('missing migration from $version');
      }
      final candidate = step.migrate(_copy(output));
      output = _copy(candidate);
      version = step.toVersion;
    }
    return output;
  }

  Map<String, Object?> _copy(Map<String, Object?> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
}
