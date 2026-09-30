// Asset License Manifest CI check (FEAT-72) — walks the package's runtime
// asset roots (`asset/`, `shaders/`) and cross-checks every file found
// against `asset/LICENSES.json` via
// `lib/core/utils/asset_license_manifest.dart`'s
// `validateAssetLicenses()`. No Flutter dependency — runs headless via
// `dart run`, same pattern as `tool/economy_sim.dart`/
// `tool/api_compatibility.dart`.
//
// Usage:
//   dart run tool/asset_license_check.dart [--root=.]
//     [--asset-roots=asset,shaders] [--manifest=asset/LICENSES.json]
//
// `--root`/`--asset-roots`/`--manifest` exist so CI can run the same generic
// checker against both this package root (`asset,shaders`) and a consumer or
// example app whose Flutter assets use a different directory convention
// (`assets`), while tests can point at a synthetic fixture directory without
// mutating real repo state.
import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/asset_license_manifest.dart';

const _defaultAssetRoots = ['asset', 'shaders'];

/// Manifest metadata files under an asset root aren't themselves a
/// shippable runtime asset needing a license entry.
const _ignoredFileNames = {'.DS_Store', 'LICENSES.json', 'LICENSES.md'};

List<String> _walkAssetPaths(String root, List<String> assetRoots) {
  final paths = <String>[];
  for (final assetRoot in assetRoots) {
    final dir = Directory('$root/$assetRoot');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(root.length + 1)
          .replaceAll('\\', '/');
      if (_ignoredFileNames.contains(relative.split('/').last)) continue;
      paths.add(relative);
    }
  }
  paths.sort();
  return paths;
}

void main(List<String> args) {
  var root = '.';
  var assetRoots = _defaultAssetRoots;
  var manifestRelPath = 'asset/LICENSES.json';
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else if (arg.startsWith('--asset-roots=')) {
      assetRoots = arg
          .substring('--asset-roots='.length)
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } else if (arg.startsWith('--manifest=')) {
      manifestRelPath = arg.substring('--manifest='.length);
    }
  }
  if (assetRoots.isEmpty) {
    stderr.writeln('--asset-roots must contain at least one directory');
    exit(64);
  }

  final assetPaths = _walkAssetPaths(root, assetRoots);
  final manifestFile = File('$root/$manifestRelPath');
  final manifest = manifestFile.existsSync()
      ? AssetLicenseManifest.fromJson(
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>,
        )
      : const AssetLicenseManifest(
          schemaVersion: assetLicenseManifestSchemaVersion,
          entries: [],
        );

  final issues = validateAssetLicenses(
    assetPaths: assetPaths,
    manifest: manifest,
  );

  stdout.writeln(
    'Asset license check — ${assetPaths.length} asset runtime, '
    '${manifest.entries.length} manifest entry.',
  );
  if (issues.isEmpty) {
    stdout.writeln('No asset license issues found.');
    exit(0);
  }

  stdout.writeln('=' * 60);
  for (final issue in issues) {
    stdout.writeln(issue);
  }
  stdout.writeln('=' * 60);
  stdout.writeln('${issues.length} issue(s) found.');
  exit(1);
}
