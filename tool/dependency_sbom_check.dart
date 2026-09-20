// Dependency Security / SBOM Gate CLI (FEAT-78) — parses pubspec.lock,
// generates a reproducible SBOM (Software Bill of Materials), classifies
// each hosted dependency's bundled LICENSE file, and cross-checks the
// result against an optional vulnerability-advisory list and a
// suppression baseline (each suppression requires an owner + expiry —
// see lib/core/utils/dependency_sbom.dart's SbomSuppression doc).
//
// No Flutter dependency in the scanned logic — runs headless via
// `dart run`, same pattern as `tool/asset_license_check.dart`.
//
// This does NOT itself scan for real vulnerabilities (no bundled CVE
// database, no network call) — `--advisories=` lets a CI job feed in
// output from a real scanner (osv-scanner, GitHub Dependabot export, a
// manually curated list).
//
// Usage:
//   dart run tool/dependency_sbom_check.dart [--lockfile=pubspec.lock]
//     [--pubspec=pubspec.yaml] [--pubCache=<dir>] [--advisories=<path>]
//     [--suppressions=<path>] [--out=<path>] [--minSeverity=low]
import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/dependency_sbom.dart';

int _severityRank(AdvisorySeverity s) => switch (s) {
  AdvisorySeverity.low => 0,
  AdvisorySeverity.medium => 1,
  AdvisorySeverity.high => 2,
  AdvisorySeverity.critical => 3,
};

/// Finds every `dependencies:` entry in [pubspecYamlContent] with no
/// version constraint AT ALL (a bare `name:` with no inline constraint
/// and no nested `sdk:`/`git:`/`path:`/`hosted:` source map) — pub
/// resolves that to "any" version, meaning a future republish (even a
/// malicious one) could silently get pulled in on the next `pub get`.
Set<String> findUnpinnedDependencies(String pubspecYamlContent) {
  final lines = pubspecYamlContent.split('\n');
  final unpinned = <String>{};
  var inDependencies = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp(r'^dependencies:\s*$').hasMatch(line)) {
      inDependencies = true;
      continue;
    }
    if (inDependencies && RegExp(r'^\S').hasMatch(line)) {
      inDependencies = false;
      continue;
    }
    if (!inDependencies) continue;
    final bareKeyMatch = RegExp(r'^  (\w[\w.]*):\s*$').firstMatch(line);
    if (bareKeyMatch == null) continue;
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    final hasNestedSpecialSource = RegExp(
      r'^\s{4,}(sdk|git|path|hosted):',
    ).hasMatch(next);
    if (!hasNestedSpecialSource) {
      unpinned.add(bareKeyMatch.group(1)!);
    }
  }
  return unpinned;
}

String? _readLicenseFile(String pubCacheDir, String package, String version) {
  final file = File('$pubCacheDir/hosted/pub.dev/$package-$version/LICENSE');
  if (!file.existsSync()) return null;
  try {
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

List<VulnerabilityAdvisory> _loadAdvisories(String? path) {
  if (path == null) return const [];
  final file = File(path);
  if (!file.existsSync()) return const [];
  final raw = jsonDecode(file.readAsStringSync()) as List<Object?>;
  return [
    for (final entry in raw)
      if (entry is Map)
        VulnerabilityAdvisory(
          package: entry['package'] as String,
          version: entry['version'] as String,
          severity: AdvisorySeverity.values.firstWhere(
            (s) => s.name == entry['severity'],
            orElse: () => AdvisorySeverity.low,
          ),
          description: entry['description'] as String? ?? '',
        ),
  ];
}

List<SbomSuppression> _loadSuppressions(String? path) {
  if (path == null) return const [];
  final file = File(path);
  if (!file.existsSync()) return const [];
  final raw = jsonDecode(file.readAsStringSync()) as List<Object?>;
  final suppressions = <SbomSuppression>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final package = entry['package'];
    final kindName = entry['kind'];
    final reason = entry['reason'];
    final owner = entry['owner'];
    final expiresAt = entry['expiresAtMs'];
    if (package is! String ||
        kindName is! String ||
        reason is! String ||
        reason.trim().isEmpty ||
        owner is! String ||
        owner.trim().isEmpty ||
        expiresAt is! int) {
      continue;
    }
    SbomIssueKind? kind;
    for (final k in SbomIssueKind.values) {
      if (k.name == kindName) {
        kind = k;
        break;
      }
    }
    if (kind == null) continue;
    suppressions.add(
      SbomSuppression(
        package: package,
        kind: kind,
        reason: reason,
        owner: owner,
        expiresAtMs: expiresAt,
      ),
    );
  }
  return suppressions;
}

void main(List<String> args) {
  var lockfilePath = 'pubspec.lock';
  var pubspecPath = 'pubspec.yaml';
  var pubCacheDir =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  String? advisoriesPath;
  String? suppressionsPath;
  String? outPath;
  var minSeverity = AdvisorySeverity.low;

  for (final arg in args) {
    if (arg.startsWith('--lockfile=')) {
      lockfilePath = arg.substring('--lockfile='.length);
    } else if (arg.startsWith('--pubspec=')) {
      pubspecPath = arg.substring('--pubspec='.length);
    } else if (arg.startsWith('--pubCache=')) {
      pubCacheDir = arg.substring('--pubCache='.length);
    } else if (arg.startsWith('--advisories=')) {
      advisoriesPath = arg.substring('--advisories='.length);
    } else if (arg.startsWith('--suppressions=')) {
      suppressionsPath = arg.substring('--suppressions='.length);
    } else if (arg.startsWith('--out=')) {
      outPath = arg.substring('--out='.length);
    } else if (arg.startsWith('--minSeverity=')) {
      final name = arg.substring('--minSeverity='.length);
      minSeverity = AdvisorySeverity.values.firstWhere(
        (s) => s.name == name,
        orElse: () => throw ArgumentError('Unknown --minSeverity=$name'),
      );
    }
  }

  final lockContent = File(lockfilePath).readAsStringSync();
  final entries = parsePubspecLock(lockContent);

  final licenseByPackage = <String, LicenseCategory>{};
  for (final entry in entries) {
    if (entry.source != DependencySource.hosted) continue;
    final text = _readLicenseFile(pubCacheDir, entry.name, entry.version);
    licenseByPackage[entry.name] = classifyLicenseText(text);
  }

  final pubspecContent = File(pubspecPath).readAsStringSync();
  final unpinned = findUnpinnedDependencies(pubspecContent);

  final versionMatch = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspecContent);
  final packageVersion = versionMatch?.group(1) ?? 'unknown';
  final nameMatch = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspecContent);
  final packageName = nameMatch?.group(1) ?? 'unknown';

  final sbom = SbomDocument(
    packageName: packageName,
    packageVersion: packageVersion,
    generatedAtMs:
        0, // fixed: keeps the SBOM byte-reproducible across runs of the same lock file
    entries: entries,
  );

  if (outPath != null) {
    File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(sbom.toJson()),
    );
  }

  final advisories = _loadAdvisories(advisoriesPath);
  final suppressions = _loadSuppressions(suppressionsPath);

  final issues = auditDependencies(
    entries: entries,
    licenseByPackage: licenseByPackage,
    nowMs: DateTime.now().millisecondsSinceEpoch,
    advisories: advisories,
    suppressions: suppressions,
    unpinnedPackages: unpinned,
  );

  stdout.writeln(
    'Dependency SBOM check — ${entries.length} package, '
    '${licenseByPackage.length} license phân loại, '
    '${suppressions.length} suppression, ${advisories.length} advisory.',
  );

  final reportable = issues
      .where((i) => _severityRank(i.severity) >= _severityRank(minSeverity))
      .toList();

  if (issues.isEmpty) {
    stdout.writeln('No dependency issues found.');
    exit(0);
  }

  stdout.writeln('=' * 60);
  for (final issue in issues) {
    stdout.writeln(issue);
  }
  stdout.writeln('=' * 60);
  stdout.writeln(
    '${issues.length} issue(s) found '
    '(${reportable.length} at/above --minSeverity=${minSeverity.name}).',
  );

  exit(reportable.isEmpty ? 0 : 1);
}
