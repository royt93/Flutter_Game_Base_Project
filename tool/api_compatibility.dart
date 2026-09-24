import 'dart:convert';
import 'dart:io';

const _entrypointRelPath = 'lib/roy_casual_kit.dart';
const _snapshotRelPath = 'tool/api_snapshot.json';

/// [args] usage: `[snapshot|check] [--root=.]`. `--root` (default `.`,
/// the real repo when invoked normally) exists so
/// `test/tool/api_compatibility_check_test.dart` can point this at a
/// synthetic fixture directory instead of the real repo, same convention
/// `tool/asset_license_check.dart`'s own `--root` already established —
/// see that file's doc comment for why (exercising a
/// removed/added-export scenario without mutating real repo state).
Future<void> main(List<String> args) async {
  var root = '.';
  final positional = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else {
      positional.add(arg);
    }
  }
  if (positional.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/api_compatibility.dart [snapshot|check] [--root=.]',
    );
    exitCode = 64;
    return;
  }
  final command = positional.isEmpty ? 'check' : positional.single;
  switch (command) {
    case 'snapshot':
      await File('$root/$_snapshotRelPath').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(await collectApiSnapshot(root)),
      );
      stdout.writeln('Wrote $_snapshotRelPath');
    case 'check':
      await checkCompatibility(root);
    default:
      stderr.writeln(
        'Usage: dart run tool/api_compatibility.dart [snapshot|check] [--root=.]',
      );
      exitCode = 64;
  }
}

Future<Map<String, Object>> collectApiSnapshot(String root) async {
  final entry = await File('$root/$_entrypointRelPath').readAsString();
  final exports = RegExp(
    r"^export '([^']+)';",
    multiLine: true,
  ).allMatches(entry).map((m) => m.group(1)!).toList()..sort();
  final symbols = <String>[];
  for (final relative in exports) {
    final source = await File('$root/lib/$relative').readAsString();
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
  return {
    'entrypoint': _entrypointRelPath,
    'exports': exports,
    'symbols': symbols,
  };
}

Future<void> checkCompatibility(String root) async {
  final snapshotFile = File('$root/$_snapshotRelPath');
  if (!snapshotFile.existsSync()) {
    throw StateError('Missing $_snapshotRelPath; run snapshot first.');
  }
  final baseline = jsonDecode(await snapshotFile.readAsString()) as Map;
  final current = await collectApiSnapshot(root);
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
  final changelog = await File('$root/CHANGELOG.md').readAsString();
  final version = _readVersion(
    await File('$root/pubspec.yaml').readAsString(),
  );
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

// BUG-74: previously used a lookahead `(?=^## |\Z)` to find the section's
// end — `\Z` isn't a valid escape in Dart's RegExp (ECMAScript syntax, not
// Perl/ICU where `\Z` means "end of string"), so it silently matched
// nothing, and the WHOLE regex failed to match at all whenever the current
// version's section was the LAST one in the file (no `## ` header after
// it to anchor on instead) — returning '' regardless of the section's
// real content. Finds the header via a plain `firstMatch`, then slices to
// either the next `## ` header or the end of the string — never relies on
// an end-of-string regex anchor at all.
String _currentChangelogSection(String changelog, String version) {
  final header = RegExp('^## $version\$', multiLine: true).firstMatch(changelog);
  if (header == null) return '';
  final bodyStart = (header.end + 1).clamp(0, changelog.length);
  final rest = changelog.substring(bodyStart);
  final nextHeader = RegExp(r'^## ', multiLine: true).firstMatch(rest);
  return nextHeader == null ? rest : rest.substring(0, nextHeader.start);
}
