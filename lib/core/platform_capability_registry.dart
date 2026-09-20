import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// This kit's classification of the running platform — coarser than
/// [TargetPlatform] (folds "on the web" in as its own kind regardless of
/// the underlying OS, since web capability differs from native regardless
/// of `TargetPlatform`).
enum PlatformKind { android, ios, web, windows, macos, linux, fuchsia }

/// Immutable, already-resolved capability snapshot for the 4 domains this
/// kit actually integrates with: haptics (`haptics.dart`), shaders
/// (`AuroraBgLayer`/`NeonAuraLayer`), local notifications
/// (`ReminderService`), and background audio (`AudioManager`).
///
/// **Compatibility policy** (documented here since it's a judgment call,
/// not a hard platform fact queried via any API): every capability is
/// assumed unsupported on the web (`PlatformKind.web`) — conservative on
/// purpose, since web support for all 4 varies by renderer/browser and a
/// false positive (assuming support that isn't there) fails silently or
/// crashes, while a false negative (assuming no support) just skips a
/// nice-to-have. Desktop (`windows`/`macos`/`linux`) has no haptic
/// feedback API, so [supportsHaptics] is false there too; the other 3
/// domains are assumed supported on every non-web platform. A consumer
/// that knows better for its specific target can always construct
/// [PlatformCapabilityRegistry] with an explicit override snapshot.
class PlatformCapabilitySnapshot {
  const PlatformCapabilitySnapshot({
    required this.platformKind,
    required this.supportsHaptics,
    required this.supportsShaders,
    required this.supportsNotifications,
    required this.supportsBackgroundAudio,
  });

  final PlatformKind platformKind;
  final bool supportsHaptics;
  final bool supportsShaders;
  final bool supportsNotifications;
  final bool supportsBackgroundAudio;
}

/// Pure detection — no platform channel, no plugin, just the 2 primitives
/// Flutter itself already resolves at process start
/// (`kIsWeb`/`defaultTargetPlatform`). [isWeb]/[targetPlatform] are
/// injectable so a device-matrix test can fixture every combination
/// without needing a real device per platform. Never throws.
PlatformCapabilitySnapshot detectPlatformCapabilities({
  bool? isWeb,
  TargetPlatform? targetPlatform,
}) {
  final web = isWeb ?? kIsWeb;
  final kind = web
      ? PlatformKind.web
      : _kindOf(targetPlatform ?? defaultTargetPlatform);
  final isDesktop =
      kind == PlatformKind.windows ||
      kind == PlatformKind.macos ||
      kind == PlatformKind.linux;
  return PlatformCapabilitySnapshot(
    platformKind: kind,
    supportsHaptics: !web && !isDesktop,
    supportsShaders: !web,
    supportsNotifications: !web,
    supportsBackgroundAudio: !web,
  );
}

PlatformKind _kindOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => PlatformKind.android,
  TargetPlatform.iOS => PlatformKind.ios,
  TargetPlatform.windows => PlatformKind.windows,
  TargetPlatform.macOS => PlatformKind.macos,
  TargetPlatform.linux => PlatformKind.linux,
  TargetPlatform.fuchsia => PlatformKind.fuchsia,
};

/// SSOT for [PlatformCapabilitySnapshot] — computed (or injected) exactly
/// once at construction and cached for the lifetime of the instance, so
/// every read is free and no code path re-queries platform state.
class PlatformCapabilityRegistry extends GetxService {
  PlatformCapabilityRegistry({PlatformCapabilitySnapshot? snapshot})
    : snapshot = snapshot ?? detectPlatformCapabilities();

  final PlatformCapabilitySnapshot snapshot;

  static PlatformCapabilityRegistry? get maybe =>
      Get.isRegistered<PlatformCapabilityRegistry>()
      ? Get.find<PlatformCapabilityRegistry>()
      : null;

  /// Runs [ifSupported] when [supported] is true, [fallback] otherwise —
  /// an explicit, testable fallback policy instead of a call site silently
  /// skipping (or worse, crashing) on an unsupported platform. A real
  /// error thrown by either branch propagates normally; this only picks
  /// which branch runs, it never swallows a bug.
  T withFallback<T>({
    required bool supported,
    required T Function() ifSupported,
    required T Function() fallback,
  }) => supported ? ifSupported() : fallback();
}
