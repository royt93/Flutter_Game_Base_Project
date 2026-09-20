List<int> _parseSemver(String version) {
  final parts = version.split('.');
  if (parts.length != 3) {
    throw ArgumentError.value(version, 'version', 'expected x.y.z semver');
  }
  return parts.map((p) {
    final n = int.tryParse(p);
    if (n == null) {
      throw ArgumentError.value(version, 'version', 'expected x.y.z semver');
    }
    return n;
  }).toList();
}

int _compareSemver(String a, String b) {
  final pa = _parseSemver(a);
  final pb = _parseSemver(b);
  for (var i = 0; i < 3; i++) {
    final cmp = pa[i].compareTo(pb[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

/// A single deprecated public API entry: pairs with a real `@Deprecated(...)`
/// annotation on the code itself, but adds the structured, machine-checkable
/// removal-version/grace-period data a plain annotation string can't carry.
class DeprecatedApi {
  DeprecatedApi({
    required this.name,
    required this.deprecatedInVersion,
    required this.removeInVersion,
    required this.migrationHint,
  }) {
    _parseSemver(deprecatedInVersion);
    _parseSemver(removeInVersion);
    if (_compareSemver(removeInVersion, deprecatedInVersion) <= 0) {
      throw ArgumentError(
        'removeInVersion ($removeInVersion) must be after '
        'deprecatedInVersion ($deprecatedInVersion)',
      );
    }
  }

  final String name;
  final String deprecatedInVersion;
  final String removeInVersion;
  final String migrationHint;
}

enum DeprecationStatus { active, pastGrace }

class DeprecationCheckResult {
  const DeprecationCheckResult({required this.api, required this.status});

  final DeprecatedApi api;
  final DeprecationStatus status;
}

/// Immutable registry of an SDK's deprecated APIs, checked against a
/// released version to find which ones are past their removal version.
class DeprecationRegistry {
  const DeprecationRegistry(this.entries);

  final List<DeprecatedApi> entries;

  List<DeprecationCheckResult> checkAll(String currentVersion) {
    _parseSemver(currentVersion);
    return entries
        .map(
          (api) => DeprecationCheckResult(
            api: api,
            status: _compareSemver(currentVersion, api.removeInVersion) >= 0
                ? DeprecationStatus.pastGrace
                : DeprecationStatus.active,
          ),
        )
        .toList();
  }

  List<DeprecationCheckResult> pastGraceOnly(String currentVersion) => checkAll(
    currentVersion,
  ).where((r) => r.status == DeprecationStatus.pastGrace).toList();
}
