/// Pure data + validation for tracking who owns/licenses each runtime
/// asset (font, audio, shader, image) a game ships — no Flutter
/// dependency, so a consumer app's own CI can run this against their own
/// asset folder the same way `tool/asset_license_check.dart` runs it
/// against this package's.
library;

/// One tracked asset's provenance. All 5 string fields are required —
/// empty-string is treated the same as missing by [validateAssetLicenses]
/// (an entry that exists but has an empty `license` is exactly as
/// unpublishable as no entry at all).
class AssetLicenseEntry {
  const AssetLicenseEntry({
    required this.path,
    required this.owner,
    required this.license,
    required this.source,
    this.attributionRequired = false,
    this.distributable = true,
  });

  /// Repo-relative path, e.g. `asset/audio/bkg.ogg` — must match exactly
  /// what a directory walk of the asset roots produces.
  final String path;
  final String owner;

  /// A license identifier — an SPDX id (`MIT`, `OFL-1.1`, `CC-BY-4.0`)
  /// where one exists, otherwise a short free-text name
  /// (`custom-original-work`). Checked against
  /// [validateAssetLicenses]'s `disallowedLicenses` denylist.
  final String license;

  /// Where this asset came from — a URL, "original work", or a
  /// purchase/marketplace name. Free text, but must be non-empty.
  final String source;
  final bool attributionRequired;

  /// `false` means this asset must never end up in a published artifact
  /// (an internal placeholder, a license that doesn't allow
  /// redistribution) — [validateAssetLicenses] flags it even if every
  /// other field is filled in correctly.
  final bool distributable;

  Map<String, Object?> toJson() => {
    'path': path,
    'owner': owner,
    'license': license,
    'source': source,
    'attributionRequired': attributionRequired,
    'distributable': distributable,
  };

  /// Returns `null` (never throws) on a malformed entry — same defensive
  /// convention as this package's other `fromJson*` parsers
  /// (`ReplayEvent.fromJson` is the exception that throws; this one
  /// follows `ReplayCapsule.fromJsonUnsigned`'s null-on-bad-shape style
  /// instead, since a manifest file is hand-edited and more likely to
  /// have a typo'd entry than a signed/trusted payload).
  static AssetLicenseEntry? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final owner = json['owner'];
    final license = json['license'];
    final source = json['source'];
    if (path is! String ||
        owner is! String ||
        license is! String ||
        source is! String) {
      return null;
    }
    return AssetLicenseEntry(
      path: path,
      owner: owner,
      license: license,
      source: source,
      attributionRequired: json['attributionRequired'] == true,
      distributable: json['distributable'] != false,
    );
  }
}

/// Current on-disk schema version for `asset/LICENSES.json` — bump this
/// (and add a migration in whatever reads an older one) on a breaking
/// shape change.
const int assetLicenseManifestSchemaVersion = 1;

/// A parsed `asset/LICENSES.json`-shaped document —
/// `{schemaVersion, entries: [...]}`.
class AssetLicenseManifest {
  const AssetLicenseManifest({
    required this.schemaVersion,
    required this.entries,
  });

  final int schemaVersion;
  final List<AssetLicenseEntry> entries;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'entries': [for (final e in entries) e.toJson()],
  };

  /// Returns an empty manifest (never throws) on a malformed document —
  /// a missing/unreadable manifest should read as "nothing is documented
  /// yet" (every asset then reports as missing) rather than crash the
  /// whole CI check.
  static AssetLicenseManifest fromJson(Map<String, Object?> json) {
    final rawEntries = json['entries'];
    final entries = <AssetLicenseEntry>[];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        if (raw is Map) {
          final entry = AssetLicenseEntry.fromJson(
            Map<String, Object?>.from(raw),
          );
          if (entry != null) entries.add(entry);
        }
      }
    }
    return AssetLicenseManifest(
      schemaVersion: assetLicenseManifestSchemaVersion,
      entries: entries,
    );
  }
}

enum AssetLicenseIssueKind {
  /// A runtime asset has no manifest entry at all.
  missing,

  /// A manifest entry's `path` no longer matches any runtime asset —
  /// stale, should be removed (or the asset was renamed and the manifest
  /// wasn't updated to match).
  stale,

  /// An entry exists but `owner`/`license`/`source` has an empty value.
  incomplete,

  /// An entry's `license` is in the denylist, or `distributable: false`.
  disallowedLicense,
}

class AssetLicenseIssue {
  const AssetLicenseIssue({
    required this.kind,
    required this.path,
    required this.detail,
  });

  final AssetLicenseIssueKind kind;
  final String path;
  final String detail;

  @override
  String toString() => '[${kind.name}] $path: $detail';
}

/// Default license-string denylist — free-text placeholders/none-of-the-
/// above values a manifest entry should never actually carry into a
/// publish. An SPDX id not on this list is NOT thereby assumed safe to
/// distribute — this is a denylist (catches known-bad), not an allowlist
/// (an unrecognized but genuinely permissive license, e.g. a public-
/// domain audio track's own custom wording, still passes through).
const Set<String> defaultDisallowedLicenses = {
  'unknown',
  'proprietary',
  'all-rights-reserved',
  'no-redistribution',
};

/// Cross-checks every path in [assetPaths] (a directory walk of the
/// asset/font/shader roots a game actually ships) against [manifest],
/// returning every mismatch found — an empty list means "clean, safe to
/// publish" as far as asset licensing goes.
List<AssetLicenseIssue> validateAssetLicenses({
  required List<String> assetPaths,
  required AssetLicenseManifest manifest,
  Set<String> disallowedLicenses = defaultDisallowedLicenses,
}) {
  final issues = <AssetLicenseIssue>[];
  final byPath = {for (final e in manifest.entries) e.path: e};
  final assetPathSet = assetPaths.toSet();

  for (final path in assetPaths) {
    final entry = byPath[path];
    if (entry == null) {
      issues.add(
        AssetLicenseIssue(
          kind: AssetLicenseIssueKind.missing,
          path: path,
          detail: 'không có entry nào trong manifest cho asset runtime này',
        ),
      );
      continue;
    }
    if (entry.owner.isEmpty || entry.license.isEmpty || entry.source.isEmpty) {
      issues.add(
        AssetLicenseIssue(
          kind: AssetLicenseIssueKind.incomplete,
          path: path,
          detail: 'thiếu owner/license/source (một hoặc nhiều field rỗng)',
        ),
      );
    }
    if (!entry.distributable) {
      issues.add(
        AssetLicenseIssue(
          kind: AssetLicenseIssueKind.disallowedLicense,
          path: path,
          detail: 'entry đánh dấu distributable: false',
        ),
      );
    } else if (disallowedLicenses.contains(entry.license)) {
      issues.add(
        AssetLicenseIssue(
          kind: AssetLicenseIssueKind.disallowedLicense,
          path: path,
          detail:
              'license "${entry.license}" nằm trong denylist, cấm phân phối',
        ),
      );
    }
  }

  for (final entry in manifest.entries) {
    if (!assetPathSet.contains(entry.path)) {
      issues.add(
        AssetLicenseIssue(
          kind: AssetLicenseIssueKind.stale,
          path: entry.path,
          detail:
              'có entry manifest nhưng không còn asset runtime nào ở path này',
        ),
      );
    }
  }

  return issues;
}
