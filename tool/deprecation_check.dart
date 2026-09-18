import 'dart:io';

import 'package:roy_casual_kit/core/utils/deprecation_registry.dart';

/// This package's own deprecated public APIs. Add an entry here alongside
/// the real `@Deprecated('...')` annotation on the code — the annotation
/// warns at compile time, this registry lets `dart run
/// tool/deprecation_check.dart` fail once the current pubspec version has
/// passed an entry's `removeInVersion`, so a scheduled removal doesn't slip.
///
/// A consuming app or CI job can run this script directly today; wiring it
/// into `.github/workflows/ci.yml` is a deliberate follow-up, not done here.
final kPackageDeprecations = <DeprecatedApi>[];

Future<void> main() async {
  final pubspecSource = await File('pubspec.yaml').readAsString();
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspecSource);
  if (match == null) {
    stderr.writeln('Could not find a version: line in pubspec.yaml');
    exitCode = 64;
    return;
  }
  final currentVersion = match.group(1)!.split('+').first;

  final registry = DeprecationRegistry(kPackageDeprecations);
  final results = registry.checkAll(currentVersion);
  final pastGrace = results
      .where((r) => r.status == DeprecationStatus.pastGrace)
      .toList();

  for (final result in results) {
    stdout.writeln(
      '${result.status == DeprecationStatus.pastGrace ? '[PAST GRACE]' : '[active]'} '
      '${result.api.name} — remove in ${result.api.removeInVersion} '
      '(current $currentVersion). ${result.api.migrationHint}',
    );
  }

  if (pastGrace.isEmpty) {
    stdout.writeln('No deprecated API past its removal version.');
    return;
  }

  stderr.writeln(
    '${pastGrace.length} deprecated API(s) past their removal version — '
    'remove them before releasing $currentVersion.',
  );
  exitCode = 1;
}
