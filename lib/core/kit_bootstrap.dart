import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_manager.dart';
import 'locale_service.dart';
import 'neon_theme.dart';
import 'performance_tier_service.dart';
import 'reminder_service.dart';
import 'storage_service.dart';

/// Optional modules that [RoyCasualKit.initialize] can register.
enum RoyCasualKitModule { storage, locale, audio, reminders, performance }

/// Immutable SDK bootstrap configuration.
class RoyCasualKitConfig {
  const RoyCasualKitConfig({
    this.modules = const {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
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
    if (requested.contains(RoyCasualKitModule.locale) &&
        !requested.contains(RoyCasualKitModule.storage) &&
        !Get.isRegistered<StorageService>()) {
      throw ArgumentError('locale module requires storage module');
    }

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
              Get.put(AudioManager(), permanent: config.permanent);
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
