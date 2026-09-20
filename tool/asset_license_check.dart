// Asset License Manifest CI check (FEAT-72) — walks the package's runtime
// asset roots (`asset/`, `shaders/`) and cross-checks every file found
// against `asset/LICENSES.json` via
// `lib/core/utils/asset_license_manifest.dart`'s
// `validateAssetLicenses()`. No Flutter dependency — runs headless via
// `dart run`, same pattern as `tool/economy_sim.dart`/
// `tool/api_compatibility.dart`.
//
// Usage:
//   dart run tool/asset_license_check.dart [--root=.] [--manifest=asset/LICENSES.json]
//
// `--root`/`--manifest` exist so `test/tool/asset_license_check_test.dart`
// can point this at a synthetic fixture directory instead of the real
// repo, without needing to mutate real repo state to exercise a
// missing/disallowed-license scenario.
import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/asset_license_manifest.dart';

const _assetRoots = ['asset', 'shaders'];

/// Manifest metadata files under an asset root aren't themselves a
/// shippable runtime asset needing a license entry.
const _ignoredFileNames = {'.DS_Store', 'LICENSES.json'};

List<String> _walkAssetPaths(String root) {
  final paths = <String>[];
  for (final assetRoot in _assetRoots) {
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
  var manifestRelPath = 'asset/LICENSES.json';
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else if (arg.startsWith('--manifest=')) {
      manifestRelPath = arg.substring('--manifest='.length);
    }
  }

  final assetPaths = _walkAssetPaths(root);
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
