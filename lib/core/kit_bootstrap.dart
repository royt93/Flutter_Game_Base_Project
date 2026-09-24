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
  storage,
  locale,
  audio,
  reminders,
  performance,
  lifecycle,
  wakeLock,
}

/// Immutable SDK bootstrap configuration.
class RoyCasualKitConfig {
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

  final Set<RoyCasualKitModule> modules;
  final SharedPreferences? preferences;
  final StorageService? storageOverride;
  final bool permanent;
}

enum RoyCasualKitStatus { initialized, degraded }

/// Result of bootstrap. A degraded result still reports successful modules so
/// a host can decide whether to continue or show its own fallback UI.
class RoyCasualKitResult {
  const RoyCasualKitResult({
    required this.status,
    required this.registeredModules,
    required this.errors,
  });

  final RoyCasualKitStatus status;
  final Set<RoyCasualKitModule> registeredModules;
  final Map<RoyCasualKitModule, Object> errors;

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
              final audio = AudioManager();
              Get.put(audio, permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<AudioManager>()) {
                  await Get.delete<AudioManager>(force: true);
                }
              });
              await audio.init();
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
              final wakeLock = WakeLockService();
              Get.put(wakeLock, permanent: config.permanent);
              _owned.add(() async {
                if (Get.isRegistered<WakeLockService>()) {
                  await Get.delete<WakeLockService>(force: true);
                }
              });
              await wakeLock.init();
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
    NeonTheme.dark = false;
    NeonTheme.colorBlindSafe = false;
  }
}
