/// Pure, no-Flutter-dependency dependency-security/SBOM (Software Bill of
/// Materials) support — parses `pubspec.lock`, classifies each
/// dependency's bundled `LICENSE` file text, and cross-checks the result
/// against an optional vulnerability-advisory list and a suppression
/// baseline. `tool/dependency_sbom_check.dart` wires this into a
/// genuinely headless `dart run` CI check.
///
/// **What this does NOT do**: scan for real CVEs. There is no bundled
/// vulnerability database and no network call here — [auditDependencies]
/// only cross-checks [DependencyEntry] against whatever
/// [VulnerabilityAdvisory] list the CALLER supplies (exported from
/// `osv-scanner`, GitHub Dependabot, or a manually curated list). Calling
/// this a "vulnerability scanner" would overstate what it is: a GATE that
/// enforces a policy over data someone else produced.
library;

/// How a package is required, from the `dependency:` field in `pubspec.lock`.
/// Any value other than `direct main` / `direct dev` is [transitive].
enum DependencyType { directMain, directDev, transitive }

/// Where a package is resolved from, from the lock file's `source:` field.
/// A missing or unrecognized value is [unknown].
enum DependencySource { hosted, sdk, git, path, unknown }

/// One resolved package from `pubspec.lock`.
class DependencyEntry {
  /// All fields are required; [version] is the resolved version string from
  /// the lock file, not a constraint.
  const DependencyEntry({
    required this.name,
    required this.version,
    required this.type,
    required this.source,
  });

  /// Package name as keyed in `pubspec.lock`.
  final String name;

  /// Resolved version string, exactly as written in the lock file.
  final String version;

  /// Direct main / direct dev / transitive.
  final DependencyType type;

  /// Hosted, SDK, git, path, or unknown.
  final DependencySource source;

  /// JSON form with `type` and `source` as enum names.
  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'type': type.name,
    'source': source.name,
  };
}

DependencyType _parseDependencyType(String raw) =>
    switch (raw.replaceAll('"', '')) {
      'direct main' => DependencyType.directMain,
      'direct dev' => DependencyType.directDev,
      _ => DependencyType.transitive,
    };

DependencySource _parseSource(String raw) => switch (raw) {
  'hosted' => DependencySource.hosted,
  'sdk' => DependencySource.sdk,
  'git' => DependencySource.git,
  'path' => DependencySource.path,
  _ => DependencySource.unknown,
};

/// Parses a `pubspec.lock` file's content into every resolved package,
/// **sorted by name** — this ordering is what makes the resulting
/// [SbomDocument] reproducible: the same lock file always produces
/// byte-identical JSON, regardless of the lock file's own key order or
/// any `Map` iteration order.
///
/// A line-based parser rather than a real YAML parser — deliberately:
/// this package has no `yaml` dependency (see `pubspec.lock` itself,
/// verified before writing this), and `pubspec.lock`'s own shape (fixed
/// 2-space-indented top-level package keys, fixed field names) is simple
/// enough that a small state machine is honest, not a fragile shortcut.
/// A line this parser doesn't recognize is skipped, never thrown on —
/// pub's own lock file format is a stable, first-party contract this
/// package doesn't control, so surviving a future minor format tweak
/// (an added field, say) matters more than being maximally strict.
///
/// A package block with no `dependency:` or no `version:` line is dropped
/// rather than reported; a missing `source:` yields [DependencySource.unknown].
List<DependencyEntry> parsePubspecLock(String content) {
  final entries = <DependencyEntry>[];
  String? currentName;
  DependencyType? currentType;
  DependencySource? currentSource;
  String? currentVersion;

  void flush() {
    if (currentName != null && currentType != null && currentVersion != null) {
      entries.add(
        DependencyEntry(
          name: currentName!,
          version: currentVersion!,
          type: currentType!,
          source: currentSource ?? DependencySource.unknown,
        ),
      );
    }
    currentName = null;
    currentType = null;
    currentSource = null;
    currentVersion = null;
  }

  final topLevelKey = RegExp(r'^  (\S+):\s*$');
  final dependencyLine = RegExp(r'^\s{4}dependency:\s*(.+)$');
  final sourceLine = RegExp(r'^\s{4}source:\s*(\S+)$');
  final versionLine = RegExp(r'^\s{4}version:\s*"?([^"\n]+)"?$');

  for (final line in content.split('\n')) {
    final keyMatch = topLevelKey.firstMatch(line);
    if (keyMatch != null) {
      flush();
      currentName = keyMatch.group(1);
      continue;
    }
    final depMatch = dependencyLine.firstMatch(line);
    if (depMatch != null) {
      currentType = _parseDependencyType(depMatch.group(1)!.trim());
      continue;
    }
    final sourceMatch = sourceLine.firstMatch(line);
    if (sourceMatch != null) {
      currentSource = _parseSource(sourceMatch.group(1)!.trim());
      continue;
    }
    final versionMatch = versionLine.firstMatch(line);
    if (versionMatch != null) {
      currentVersion = versionMatch.group(1)!.trim();
      continue;
    }
  }
  flush();

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// A reproducible bill-of-materials document — `toJson()`'s `entries`
/// list is always in the same (name-sorted) order [parsePubspecLock]
/// already guarantees, so hashing/diffing 2 SBOMs of the same lock file
/// is meaningful.
class SbomDocument {
  /// [generatedAtMs] is a caller-supplied epoch-millisecond timestamp.
  const SbomDocument({
    required this.packageName,
    required this.packageVersion,
    required this.generatedAtMs,
    required this.entries,
  });

  /// Version of this document's JSON shape, written into [toJson].
  static const int schemaVersion = 1;

  /// Name of the package the SBOM describes.
  final String packageName;

  /// Version of that package.
  final String packageVersion;

  /// When the document was generated (epoch ms, as given by the caller).
  /// It differs between runs, so leave it out when diffing two SBOMs.
  final int generatedAtMs;

  /// Resolved dependencies, name-sorted when built from [parsePubspecLock].
  final List<DependencyEntry> entries;

  /// JSON form: `schemaVersion`, package fields, `generatedAtMs`, and the
  /// `entries` list in their given order.
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'packageName': packageName,
    'packageVersion': packageVersion,
    'generatedAtMs': generatedAtMs,
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// A `LICENSE` file's text, reduced to one of 3 buckets — deliberately
/// coarse (not "is this exact SPDX id compatible with our own license"):
/// this is a policy GATE flagging "needs a human to look," not a legal
/// compatibility engine.
enum LicenseCategory { permissive, copyleft, unknown }

const _permissiveMarkers = [
  'MIT License',
  'The MIT License',
  // The MIT license's own canonical opening sentence — many published
  // LICENSE files paste this body WITHOUT ever titling it "MIT License"
  // (found on the real `uuid` package while testing this against this
  // repo's own pubspec.lock).
  'Permission is hereby granted, free of charge, to any person obtaining a copy',
  'BSD ',
  // The dart.dev/Google-authored BSD-3-Clause boilerplate never spells out
  // "BSD" as a word — found by actually running this against every
  // package in this repo's own pubspec.lock (60+ false "unknown" results,
  // ALL Dart/Flutter-team packages using this exact phrasing) rather than
  // assumed from a license-name-only heuristic.
  'Redistribution and use in source and binary forms',
  'Apache License',
  'ISC License',
  'zlib License',
];
const _copyleftMarkers = [
  'GNU GENERAL PUBLIC LICENSE',
  'GNU LESSER GENERAL PUBLIC LICENSE',
  'GNU AFFERO GENERAL PUBLIC LICENSE',
];

/// Classifies a `LICENSE` file's raw text by matching well-known license
/// header text — case-sensitive on purpose (a license file's own actual
/// wording is what a legal reviewer would look at too, a lowercase
/// substring match risks matching unrelated prose).
///
/// Returns [LicenseCategory.unknown] for `null` or blank text. Copyleft
/// markers are checked before permissive ones, so a text containing both is
/// [LicenseCategory.copyleft].
LicenseCategory classifyLicenseText(String? licenseFileContent) {
  if (licenseFileContent == null || licenseFileContent.trim().isEmpty) {
    return LicenseCategory.unknown;
  }
  for (final marker in _copyleftMarkers) {
    if (licenseFileContent.contains(marker)) return LicenseCategory.copyleft;
  }
  for (final marker in _permissiveMarkers) {
    if (licenseFileContent.contains(marker)) return LicenseCategory.permissive;
  }
  return LicenseCategory.unknown;
}

/// How serious an advisory or audit issue is, from [low] up to [critical].
enum AdvisorySeverity { low, medium, high, critical }

/// One vulnerability advisory — supplied by the CALLER (see this file's
/// doc comment), never produced by this file itself.
class VulnerabilityAdvisory {
  /// An advisory applies to exactly one [package] at one [version].
  const VulnerabilityAdvisory({
    required this.package,
    required this.version,
    required this.severity,
    required this.description,
  });

  /// Name of the affected package.
  final String package;

  /// Exact affected version; matched with `==` against a lock entry's version,
  /// so a range is not understood.
  final String version;

  /// Severity copied onto the resulting [SbomIssue].
  final AdvisorySeverity severity;

  /// Text copied onto the resulting [SbomIssue.detail].
  final String description;
}

/// A pre-approved exception — [owner] and [expiresAtMsAfterEpoch] are
/// both required (not optional) because an unowned or permanent
/// suppression is exactly the "false positive with no accountability and
/// no forced re-review" this task's acceptance criteria calls out. Once
/// [expiresAtMsAfterEpoch] has passed (checked against
/// [auditDependencies]'s own `nowMs`), the suppression simply stops
/// applying — no special "expired" state to handle, the issue just
/// reappears in the next audit.
class SbomSuppression {
  /// Every field is required so an exception always names its package, issue
  /// kind, justification, owner and expiry.
  const SbomSuppression({
    required this.package,
    required this.kind,
    required this.reason,
    required this.owner,
    required this.expiresAtMs,
  });

  /// Package the exception applies to.
  final String package;

  /// Which issue kind it silences; other kinds for the same package still
  /// appear.
  final SbomIssueKind kind;

  /// Why the issue is accepted.
  final String reason;

  /// Person or team accountable for re-reviewing it.
  final String owner;

  /// Epoch ms after which the suppression stops applying. It is active only
  /// while this is strictly greater than the audit's `nowMs`.
  final int expiresAtMs;
}

/// The kinds of problem [auditDependencies] can report.
enum SbomIssueKind {
  /// No `LICENSE` text, or it matched no known header. Hosted packages only.
  unknownLicense,

  /// License text matched a GPL/LGPL/AGPL header. Hosted packages only.
  copyleftLicense,

  /// A supplied [VulnerabilityAdvisory] matched a package at its exact version.
  vulnerability,

  /// A package named in `unpinnedPackages` has no version constraint.
  unpinnedConstraint,
}

/// One problem found by [auditDependencies] that no unexpired suppression
/// covers.
class SbomIssue {
  const SbomIssue({
    required this.package,
    required this.kind,
    required this.severity,
    required this.detail,
  });

  /// Package the issue is about.
  final String package;

  /// What kind of problem it is.
  final SbomIssueKind kind;

  /// Severity: `high` for copyleft, `low` for unknown license, `medium` for
  /// unpinned, and the advisory's own severity for a vulnerability.
  final AdvisorySeverity severity;

  /// Human-readable explanation.
  final String detail;

  @override
  String toString() => '[${severity.name}] $package: ${kind.name} — $detail';
}

/// Cross-checks [entries] against license classifications, an optional
/// [advisories] list, and [pinnedOnly] policy, returning every issue not
/// covered by an unexpired [SbomSuppression].
///
/// [licenseByPackage] maps a hosted package's name to its
/// [classifyLicenseText] result — a package this map has no entry for
/// (e.g. its `LICENSE` file couldn't be read) is treated as
/// [LicenseCategory.unknown], same as an empty/unparseable one.
///
/// License checks run for [DependencySource.hosted] entries only; SDK, git and
/// path packages are skipped. An advisory matches when any entry (any source)
/// has the same name and exact version. [unpinnedPackages] lists package names
/// whose `pubspec.yaml` constraint is `any`; each yields one issue. A
/// suppression applies when package and kind match and its expiry is after
/// [nowMs]. Issues come back license first (in entry order), then
/// vulnerabilities, then unpinned.
List<SbomIssue> auditDependencies({
  required List<DependencyEntry> entries,
  required Map<String, LicenseCategory> licenseByPackage,
  required int nowMs,
  List<VulnerabilityAdvisory> advisories = const [],
  List<SbomSuppression> suppressions = const [],
  Set<String> unpinnedPackages = const {},
}) {
  bool suppressed(String package, SbomIssueKind kind) => suppressions.any(
    (s) => s.package == package && s.kind == kind && s.expiresAtMs > nowMs,
  );

  final issues = <SbomIssue>[];

  for (final entry in entries) {
    if (entry.source != DependencySource.hosted) continue;
    final category = licenseByPackage[entry.name] ?? LicenseCategory.unknown;
    if (category == LicenseCategory.copyleft &&
        !suppressed(entry.name, SbomIssueKind.copyleftLicense)) {
      issues.add(
        SbomIssue(
          package: entry.name,
          kind: SbomIssueKind.copyleftLicense,
          severity: AdvisorySeverity.high,
          detail:
              'license copyleft (GPL/LGPL/AGPL họ) — cần review pháp lý trước khi publish',
        ),
      );
    } else if (category == LicenseCategory.unknown &&
        !suppressed(entry.name, SbomIssueKind.unknownLicense)) {
      issues.add(
        SbomIssue(
          package: entry.name,
          kind: SbomIssueKind.unknownLicense,
          severity: AdvisorySeverity.low,
          detail:
              'không xác định được license (thiếu LICENSE file hoặc không khớp header đã biết)',
        ),
      );
    }
  }

  for (final advisory in advisories) {
    final match = entries.any(
      (e) => e.name == advisory.package && e.version == advisory.version,
    );
    if (match && !suppressed(advisory.package, SbomIssueKind.vulnerability)) {
      issues.add(
        SbomIssue(
          package: advisory.package,
          kind: SbomIssueKind.vulnerability,
          severity: advisory.severity,
          detail: advisory.description,
        ),
      );
    }
  }

  for (final package in unpinnedPackages) {
    if (!suppressed(package, SbomIssueKind.unpinnedConstraint)) {
      issues.add(
        SbomIssue(
          package: package,
          kind: SbomIssueKind.unpinnedConstraint,
          severity: AdvisorySeverity.medium,
          detail:
              'pubspec.yaml không giới hạn version (any) — có thể resolve bất kỳ bản nào kể cả bản hỏng/độc hại',
        ),
      );
    }
  }

  return issues;
}
