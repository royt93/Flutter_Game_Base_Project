import 'dart:convert';
import 'dart:io';

const _entrypoint = 'lib/roy_casual_kit.dart';
const _snapshotPath = 'tool/api_snapshot.json';

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'check' : args.single;
  switch (command) {
    case 'snapshot':
      await File(_snapshotPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(await collectApiSnapshot()),
      );
      stdout.writeln('Wrote $_snapshotPath');
    case 'check':
      await checkCompatibility();
    default:
      stderr.writeln(
        'Usage: dart run tool/api_compatibility.dart [snapshot|check]',
      );
      exitCode = 64;
  }
}

Future<Map<String, Object>> collectApiSnapshot() async {
  final entry = await File(_entrypoint).readAsString();
  final exports = RegExp(
    r"^export '([^']+)';",
    multiLine: true,
  ).allMatches(entry).map((m) => m.group(1)!).toList()..sort();
  final symbols = <String>[];
  for (final relative in exports) {
    final source = await File('lib/$relative').readAsString();
    for (final match in RegExp(
      r'^(?:abstract\s+)?(?:class|enum|mixin|typedef|extension)\s+([A-Za-z_]\w*)',
      multiLine: true,
    ).allMatches(source)) {
      symbols.add('$relative:${match.group(1)}');
    }
    for (final match in RegExp(
      r'^(?:const|final)\s+([A-Za-z_]\w*)\s*=|^([A-Za-z_]\w*)\s*\([^;]*\)\s*\{',
      multiLine: true,
    ).allMatches(source)) {
      symbols.add('$relative:${match.group(1) ?? match.group(2)}');
    }
  }
  symbols.sort();
  return {'entrypoint': _entrypoint, 'exports': exports, 'symbols': symbols};
}

Future<void> checkCompatibility() async {
  final snapshotFile = File(_snapshotPath);
  if (!snapshotFile.existsSync()) {
    throw StateError('Missing $_snapshotPath; run snapshot first.');
  }
  final baseline = jsonDecode(await snapshotFile.readAsString()) as Map;
  final current = await collectApiSnapshot();
  final baselineExports = Set<String>.from(baseline['exports'] as List);
  final currentExports = Set<String>.from(current['exports'] as List);
  final baselineSymbols = Set<String>.from(baseline['symbols'] as List);
  final currentSymbols = Set<String>.from(current['symbols'] as List);
  final removed = {
    ...baselineExports.difference(currentExports),
    ...baselineSymbols.difference(currentSymbols),
  };
  final added = {
    ...currentExports.difference(baselineExports),
    ...currentSymbols.difference(baselineSymbols),
  };

  if (removed.isEmpty && added.isEmpty) {
    stdout.writeln('API compatibility: unchanged');
    return;
  }
  final changelog = await File('CHANGELOG.md').readAsString();
  final version = _readVersion(await File('pubspec.yaml').readAsString());
  final section = _currentChangelogSection(changelog, version);
  if (removed.isNotEmpty &&
      !_isMajor(version) &&
      !section.contains('BREAKING')) {
    throw StateError(
      'Breaking API removals require a major version or BREAKING changelog entry: $removed',
    );
  }
  if (added.isNotEmpty && section.isEmpty) {
    throw StateError('API additions require a changelog section for $version.');
  }
  stdout.writeln(
    'API compatibility: ${removed.isEmpty ? 'additive' : 'breaking'}',
  );
  stdout.writeln('Added: $added');
  stdout.writeln('Removed: $removed');
}

String _readVersion(String yaml) => RegExp(
  r'^version:\s*([^\s]+)',
  multiLine: true,
).firstMatch(yaml)!.group(1)!;

bool _isMajor(String version) => int.parse(version.split('.').first) > 0;

String _currentChangelogSection(String changelog, String version) {
  final match = RegExp(
    '^## \\$version\\n(.*?)(?=^## |\\Z)',
    multiLine: true,
    dotAll: true,
  ).firstMatch(changelog);
  return match?.group(1) ?? '';
}
