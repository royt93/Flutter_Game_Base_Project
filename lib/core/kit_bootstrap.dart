import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_manager.dart';
import 'locale_service.dart';
import 'lifecycle_coordinator.dart';
import 'neon_theme.dart';
import 'performance_tier_service.dart';
import 'reminder_service.dart';
import 'storage_service.dart';
import 'wake_lock_service.dart';

/// Optional modules that [RoyCasualKit.initialize] can register.
enum RoyCasualKitModule {
  /// [StorageService]; built from [RoyCasualKitConfig.storageOverride], else
  /// [RoyCasualKitConfig.preferences], else the real `SharedPreferences`.
  storage,

  /// [LocaleService]; fails with a [StateError] unless [StorageService] is
  /// already registered (request [storage] too, or register it yourself).
  locale,

  /// [AudioManager]; `init()` runs before registration, so a failed init
  /// leaves nothing registered and a retry starts clean.
  audio,

  /// [ReminderService].
  reminders,

  /// [PerformanceTierService].
  performance,

  /// [RoyLifecycleCoordinator].
  lifecycle,

  /// [WakeLockService]; needs [StorageService] registered (its `init()`
  /// reads the saved preference) and, like [audio], inits before registering.
  wakeLock,
}

/// Immutable SDK bootstrap configuration.
class RoyCasualKitConfig {
  /// [modules] defaults to storage + locale + lifecycle. [permanent] is
  /// forwarded unchanged to every `Get.put` the bootstrap performs.
  const RoyCasualKitConfig({
    this.modules = const {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
      RoyCasualKitModule.lifecycle,
    },
    this.preferences,
    this.storageOverride,
    this.permanent = true,
  });

  /// Modules to register; each is skipped if its service is already registered.
  final Set<RoyCasualKitModule> modules;

  /// Pre-opened `SharedPreferences` for the storage module (e.g. a test's
  /// mock instance); `null` opens the real one.
  final SharedPreferences? preferences;

  /// A ready-made [StorageService] to register as-is; takes precedence over
  /// [preferences].
  final StorageService? storageOverride;

  /// Passed as `permanent` to every `Get.put` the bootstrap performs.
  final bool permanent;
}

/// Overall outcome of [RoyCasualKit.initialize].
enum RoyCasualKitStatus {
  /// Every requested module is registered.
  initialized,

  /// At least one requested module threw; see [RoyCasualKitResult.errors].
  degraded,
}

/// Result of bootstrap. A degraded result still reports successful modules so
/// a host can decide whether to continue or show its own fallback UI.
class RoyCasualKitResult {
  const RoyCasualKitResult({
    required this.status,
    required this.registeredModules,
    required this.errors,
  });

  /// [RoyCasualKitStatus.degraded] iff [errors] is non-empty.
  final RoyCasualKitStatus status;

  /// Modules registered so far — includes ones registered by an earlier
  /// [RoyCasualKit.initialize] call, not just this one.
  final Set<RoyCasualKitModule> registeredModules;

  /// The error each failed module threw during this call; a failure never
  /// aborts the remaining modules.
  final Map<RoyCasualKitModule, Object> errors;

  /// Shorthand for `status == RoyCasualKitStatus.degraded`.
  bool get isDegraded => status == RoyCasualKitStatus.degraded;
}

/// Idempotent GetX service bootstrap for consumer apps.
class RoyCasualKit {
  RoyCasualKit._();

  static RoyCasualKitResult? _result;
  static Future<RoyCasualKitResult>? _pending;
  static final _owned = <Future<void> Function()>[];

  /// The most recent [initialize] call's own return value (IDEA-64) —
  /// `null` before [initialize] has ever been called. [initialize] itself
  /// only hands this to its ONE caller at boot time; this is the seam a
  /// debug/QA panel (or anything else that wants to inspect boot health
  /// later) reads from instead — never mutated except by [initialize]/
  /// [resetForTesting].
  static RoyCasualKitResult? get lastResult => _result;

  /// Registers the modules in [config], in enum order, skipping any service
  /// that is already registered, so repeat calls are safe. Never throws: a
  /// module that fails is recorded in [RoyCasualKitResult.errors] and the
  /// result is [RoyCasualKitStatus.degraded]; re-calling retries it. A call
  /// made while another is still running returns that call's future (its
  /// [config] is ignored).
  static Future<RoyCasualKitResult> initialize({
    RoyCasualKitConfig config = const RoyCasualKitConfig(),
  }) {
    final pending = _pending;
    if (pending != null) return pending;
    final future = _initialize(config);
    _pending = future;
    return future.whenComplete(() => _pending = null);
  }

  static Future<RoyCasualKitResult> _initialize(
    RoyCasualKitConfig config,
  ) async {
    final requested = Set<RoyCasualKitModule>.from(config.modules);

    final errors = <RoyCasualKitModule, Object>{};
    final registered = <RoyCasualKitModule>{...?_result?.registeredModules};
    for (final module in RoyCasualKitModule.values) {
      if (!requested.contains(module)) continue;
      try {
        switch (module) {
          case RoyCasualKitModule.storage:
            if (!Get.isRegistered<StorageService>()) {
              final storage =
                  config.storageOverride ??
                  StorageService(
                    config.preferences ?? await SharedPreferences.getInstance(),
                  );
              Get.put(storage, permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<StorageService>()) {
                  await Get.delete<StorageService>(force: true);
                }
              });
            }
          case RoyCasualKitModule.locale:
            if (!Get.isRegistered<LocaleService>()) {
              if (!Get.isRegistered<StorageService>()) {
                throw StateError('locale module requires storage module');
              }
              Get.put(
                LocaleService(StorageService.to),
                permanent: config.permanent,
              );
              _owned.add(() async {
                if (Get.isRegistered<LocaleService>()) {
                  await Get.delete<LocaleService>(force: true);
                }
              });
            }
          case RoyCasualKitModule.audio:
            if (!Get.isRegistered<AudioManager>()) {
              // BUG-86: init() BEFORE Get.put — if init() throws, nothing
              // is registered at all, so a retried initialize() re-attempts
              // cleanly instead of finding isRegistered==true and skipping
              // this whole branch forever with a half-initialized instance.
              final audio = AudioManager();
              await audio.init();
              Get.put(audio, permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<AudioManager>()) {
                  await Get.delete<AudioManager>(force: true);
                }
              });
            }
          case RoyCasualKitModule.reminders:
            if (!Get.isRegistered<ReminderService>()) {
              Get.put(ReminderService(), permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<ReminderService>()) {
                  await Get.delete<ReminderService>(force: true);
                }
              });
            }
          case RoyCasualKitModule.performance:
            if (!Get.isRegistered<PerformanceTierService>()) {
              Get.put(PerformanceTierService(), permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<PerformanceTierService>()) {
                  await Get.delete<PerformanceTierService>(force: true);
                }
              });
            }
          case RoyCasualKitModule.lifecycle:
            if (!Get.isRegistered<RoyLifecycleCoordinator>()) {
              Get.put(RoyLifecycleCoordinator(), permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<RoyLifecycleCoordinator>()) {
                  await Get.delete<RoyLifecycleCoordinator>(force: true);
                }
              });
            }
          case RoyCasualKitModule.wakeLock:
            if (!Get.isRegistered<WakeLockService>()) {
              // BUG-86: same init-before-put fix as the audio branch above.
              final wakeLock = WakeLockService();
              await wakeLock.init();
              Get.put(wakeLock, permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<WakeLockService>()) {
                  await Get.delete<WakeLockService>(force: true);
                }
              });
            }
        }
        registered.add(module);
      } catch (error) {
        errors[module] = error;
      }
    }
    final result = RoyCasualKitResult(
      status: errors.isEmpty
          ? RoyCasualKitStatus.initialized
          : RoyCasualKitStatus.degraded,
      registeredModules: Set.unmodifiable(registered),
      errors: Map.unmodifiable(errors),
    );
    _result = result;
    return result;
  }

  /// Clears only registrations created by the SDK. Intended for tests and
  /// host-controlled teardown; consumer-owned pre-existing services survive.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    for (final dispose in _owned.reversed) {
      await dispose();
    }
    _owned.clear();
    _result = null;
    _pending = null;
    NeonTheme.resetPalette();
    NeonTheme.dark = false;
    NeonTheme.colorBlindSafe = false;
  }
}
