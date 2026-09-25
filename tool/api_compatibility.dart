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
  final pubspecFile = File('$root/pubspec.yaml');
  final version = pubspecFile.existsSync()
      ? _readVersion(await pubspecFile.readAsString())
      : null;
  final exports = RegExp(
    r"^export '([^']+)';",
    multiLine: true,
  ).allMatches(entry).map((m) => m.group(1)!).toList()..sort();
  final symbols = <String>[];
  for (final relative in exports) {
    final source = await File('$root/lib/$relative').readAsString();
    // 1. Classes, enums, mixins, typedefs, extensions, extension types with modern Dart modifiers
    for (final match in RegExp(
      r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*(?:class|enum|mixin|typedef|extension(?:\s+type)?)\s+([A-Za-z][A-Za-z0-9_]*)',
      multiLine: true,
    ).allMatches(source)) {
      symbols.add('$relative:${match.group(1)}');
    }
    // 2. Top-level const / final
    for (final match in RegExp(
      r'^(?:const|final)\s+(?:[A-Za-z0-9_<>,?\s]+\s+)?([A-Za-z][A-Za-z0-9_]*)\s*=',
      multiLine: true,
    ).allMatches(source)) {
      symbols.add('$relative:${match.group(1)}');
    }
    // 3. Top-level typed functions (block or arrow) and getters/setters
    for (final match in RegExp(
      r'^(?:(?:external\s+)?(?:(?:void|[A-Za-z][A-Za-z0-9_<>.,?]*)\s+)?(?:(get|set)\s+)?([A-Za-z][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*(?:\([^;]*?\)|(?<=\bget\s+[A-Za-z][A-Za-z0-9_]*))\s*(?:async\*?|sync\*?)?\s*(?:=>|\{))',
      multiLine: true,
    ).allMatches(source)) {
      final name = match.group(2)!;
      const reserved = {
        'if',
        'for',
        'while',
        'switch',
        'return',
        'class',
        'enum',
        'mixin',
        'typedef',
        'extension',
        'const',
        'final',
        'assert',
      };
      if (!reserved.contains(name)) {
        symbols.add('$relative:$name');
      }
    }
  }
  symbols.sort();
  final result = <String, Object>{
    'version': ?version,
    'entrypoint': _entrypointRelPath,
    'exports': exports,
    'symbols': symbols,
  };
  return result;
}

Future<void> checkCompatibility(String root) async {
  final snapshotFile = File('$root/$_snapshotRelPath');
  if (!snapshotFile.existsSync()) {
    throw StateError('Missing $_snapshotRelPath; run snapshot first.');
  }
  final baseline = jsonDecode(await snapshotFile.readAsString()) as Map;
  final baselineVersion = baseline['version'] as String?;
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
  final isMajor = _isMajorBump(version, baselineVersion);
  if (removed.isNotEmpty &&
      !isMajor &&
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
  r'^version:\s*([^\s+]+)',
  multiLine: true,
).firstMatch(yaml)!.group(1)!;

({int major, int minor, int patch})? _parseSemver(String version) {
  final clean = version.split('+').first.split('-').first;
  final parts = clean.split('.');
  if (parts.length != 3) return null;
  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = int.tryParse(parts[2]);
  if (major == null || minor == null || patch == null) return null;
  return (major: major, minor: minor, patch: patch);
}

bool _isMajorBump(String currentVersion, String? baselineVersion) {
  if (baselineVersion == null) return false;
  final current = _parseSemver(currentVersion);
  final baseline = _parseSemver(baselineVersion);
  if (current == null || baseline == null) return false;
  return current.major > baseline.major;
}

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
