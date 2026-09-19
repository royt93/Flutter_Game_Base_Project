import 'package:get/get.dart';

import 'remote_config_service.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';

/// What an app should show for the current version/maintenance state.
/// Ordered by severity: [maintenance] and [forceUpdate] block play,
/// [softUpdate] is dismissible, [ok] shows nothing.
enum GateDecision { ok, softUpdate, forceUpdate, maintenance }

/// A parsed `MAJOR.MINOR.PATCH[-prerelease][+build]` version, per
/// semver.org — [_compareCore] only ever looks at major/minor/patch/
/// prerelease; build metadata is parsed (so a trailing `+...` doesn't
/// make the whole string invalid) but never affects ordering.
class _Semver {
  const _Semver({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
  });

  final int major;
  final int minor;
  final int patch;

  /// `null` = no prerelease tag (a released version).
  final String? prerelease;

  static _Semver? tryParse(String input) {
    final withoutBuild = input.split('+').first;
    final parts = withoutBuild.split('-');
    final core = parts.first.split('.');
    if (core.length != 3) return null;
    final major = int.tryParse(core[0]);
    final minor = int.tryParse(core[1]);
    final patch = int.tryParse(core[2]);
    if (major == null || minor == null || patch == null) return null;
    final prerelease = parts.length > 1 ? parts.sublist(1).join('-') : null;
    return _Semver(major: major, minor: minor, patch: patch, prerelease: prerelease);
  }
}

/// Compares [a] to [b] as semver strings, per this policy:
/// - Major/minor/patch compare numerically first.
/// - Equal core version: a prerelease tag (`-beta`, `-rc.1`, ...) sorts
///   BEFORE the same core version with no prerelease (`1.2.3-beta` <
///   `1.2.3`) — a prerelease is not yet the real release.
/// - Build metadata (`+001`) is ignored entirely, never affects ordering.
/// - Either string failing to parse (not `x.y.z[-pre][+build]`) returns
///   `null` — never throws, never guesses an order for invalid input.
int? compareAppVersions(String a, String b) {
  final va = _Semver.tryParse(a);
  final vb = _Semver.tryParse(b);
  if (va == null || vb == null) return null;

  final coreCompare = [
    va.major.compareTo(vb.major),
    va.minor.compareTo(vb.minor),
    va.patch.compareTo(vb.patch),
  ].firstWhere((c) => c != 0, orElse: () => 0);
  if (coreCompare != 0) return coreCompare;

  if (va.prerelease == vb.prerelease) return 0;
  if (va.prerelease == null) return 1; // a is a release, b is a prerelease
  if (vb.prerelease == null) return -1; // a is a prerelease, b is a release
  return va.prerelease!.compareTo(vb.prerelease!);
}

/// Immutable version-gate policy — from a bundled asset default, a remote
/// override (via [AppVersionGateController]), or built directly for a pure
/// [evaluateVersionGate] call/test.
class AppVersionGateConfig {
  const AppVersionGateConfig({
    this.minimumVersion,
    this.recommendedVersion,
    this.maintenanceActive = false,
    this.maintenanceMessage,
    this.storeUrl,
  });

  final String? minimumVersion;
  final String? recommendedVersion;
  final bool maintenanceActive;
  final String? maintenanceMessage;
  final String? storeUrl;
}

/// Pure decision function — no I/O, no singletons, easy to fixture-test.
///
/// **Safety-first**: any invalid input (an unparseable [currentVersion], or
/// an unparseable [AppVersionGateConfig.minimumVersion]/
/// [AppVersionGateConfig.recommendedVersion]) is treated as "can't tell, so
/// don't block" — a corrupt or malformed config can degrade to [ok] but can
/// never force-block a user who did nothing wrong. Only
/// [AppVersionGateConfig.maintenanceActive] (a plain bool, can't be
/// "invalid") can force/maintenance-gate independent of version parsing.
GateDecision evaluateVersionGate({
  required String currentVersion,
  required AppVersionGateConfig config,
}) {
  if (config.maintenanceActive) return GateDecision.maintenance;

  final minimum = config.minimumVersion;
  if (minimum != null) {
    final cmp = compareAppVersions(currentVersion, minimum);
    if (cmp != null && cmp < 0) return GateDecision.forceUpdate;
  }

  final recommended = config.recommendedVersion;
  if (recommended != null) {
    final cmp = compareAppVersions(currentVersion, recommended);
    if (cmp != null && cmp < 0) return GateDecision.softUpdate;
  }

  return GateDecision.ok;
}

/// Reads version-gate policy from a [RemoteConfigService] (which already
/// gives "asset default, remote merges in, remote fail/corrupt keeps
/// last-good" for free — see `ENH-58`) and evaluates it — no separate
/// cache of its own, since [RemoteConfigService] already *is* the
/// last-known-good cache. Keys read: `appVersionMinimum`,
/// `appVersionRecommended`, `appVersionMaintenanceActive`,
/// `appVersionMaintenanceMessage`, `appVersionStoreUrl`.
///
/// Also tracks the soft-update prompt's own cooldown — a dismissible
/// prompt re-shown every single launch is just noise.
class AppVersionGateController extends GetxService {
  AppVersionGateController({
    required this.remoteConfig,
    this.softPromptCooldown = const Duration(days: 3),
  });

  final RemoteConfigService remoteConfig;
  final Duration softPromptCooldown;

  static AppVersionGateController? get maybe =>
      Get.isRegistered<AppVersionGateController>()
      ? Get.find<AppVersionGateController>()
      : null;

  AppVersionGateConfig get config {
    String? nonEmpty(String key) {
      final value = remoteConfig.getString(key);
      return value.isEmpty ? null : value;
    }

    return AppVersionGateConfig(
      minimumVersion: nonEmpty('appVersionMinimum'),
      recommendedVersion: nonEmpty('appVersionRecommended'),
      maintenanceActive: remoteConfig.getBool('appVersionMaintenanceActive'),
      maintenanceMessage: nonEmpty('appVersionMaintenanceMessage'),
      storeUrl: nonEmpty('appVersionStoreUrl'),
    );
  }

  GateDecision decisionFor(String currentVersion) =>
      evaluateVersionGate(currentVersion: currentVersion, config: config);

  bool get softPromptDue {
    final lastMs = StorageService.to.getInt(
      StorageKeys.appVersionSoftPromptLastMs,
      def: 0,
    );
    if (lastMs == 0) return true;
    return nowMsClamped() - lastMs >= softPromptCooldown.inMilliseconds;
  }

  /// Block body (not `=> StorageService.to.setInt(...)`) on purpose — an
  /// arrow body would still hand the underlying `Future` back to the
  /// caller at runtime despite the `void` return type, which trips
  /// `setState`'s "callback returned a Future" assertion for any caller
  /// wrapping this in `setState(() => controller.recordSoftPromptDismissed())`
  /// (exactly how `AppVersionGateOverlay.onSoftDismiss` is typically used).
  void recordSoftPromptDismissed() {
    StorageService.to.setInt(StorageKeys.appVersionSoftPromptLastMs, nowMsClamped());
  }
}
