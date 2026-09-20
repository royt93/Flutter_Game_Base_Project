// Accessibility Audit CLI (FEAT-76) — walks a widget source tree
// (default: `lib/presentation/widgets/`) and runs
// `lib/core/utils/accessibility_audit.dart`'s `scanAccessibility()`
// against every `.dart` file found, printing violations grouped by
// severity. No Flutter dependency in the scanned logic itself — runs
// headless via `dart run`, same pattern as
// `tool/asset_license_check.dart`/`tool/deprecation_check.dart`.
//
// Usage:
//   dart run tool/accessibility_audit_check.dart [--root=lib/presentation/widgets]
//     [--baseline=tool/accessibility_audit_baseline.json] [--minSeverity=warning]
import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/accessibility_audit.dart';

List<String> _walkDartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final paths = <String>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}

int _severityRank(AuditSeverity s) => switch (s) {
  AuditSeverity.info => 0,
  AuditSeverity.warning => 1,
  AuditSeverity.error => 2,
};

void main(List<String> args) {
  var root = 'lib/presentation/widgets';
  var baselinePath = 'tool/accessibility_audit_baseline.json';
  var minSeverity = AuditSeverity.warning;
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else if (arg.startsWith('--baseline=')) {
      baselinePath = arg.substring('--baseline='.length);
    } else if (arg.startsWith('--minSeverity=')) {
      final name = arg.substring('--minSeverity='.length);
      minSeverity = AuditSeverity.values.firstWhere(
        (s) => s.name == name,
        orElse: () => throw ArgumentError('Unknown --minSeverity=$name'),
      );
    }
  }

  final baselineFile = File(baselinePath);
  final baseline = baselineFile.existsSync()
      ? AuditBaseline.fromJson(jsonDecode(baselineFile.readAsStringSync()) as List<Object?>)
      : AuditBaseline.empty;

  final files = _walkDartFiles(root);
  final fileContents = {for (final f in files) f: File(f).readAsStringSync()};

  final violations = scanAccessibility(fileContents: fileContents, baseline: baseline);

  stdout.writeln(
    'Accessibility audit — ${files.length} file quét, '
    '${baseline.suppressions.length} baseline suppression.',
  );

  final reportable = violations
      .where((v) => _severityRank(v.severity) >= _severityRank(minSeverity))
      .toList();

  if (violations.isEmpty) {
    stdout.writeln('No accessibility issues found.');
    exit(0);
  }

  stdout.writeln('=' * 60);
  for (final v in violations) {
    stdout.writeln(v);
  }
  stdout.writeln('=' * 60);
  stdout.writeln(
    '${violations.length} issue(s) found '
    '(${reportable.length} at/above --minSeverity=${minSeverity.name}).',
  );

  exit(reportable.isEmpty ? 0 : 1);
}
