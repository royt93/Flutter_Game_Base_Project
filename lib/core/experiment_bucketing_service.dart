import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/fnv1a.dart';

/// Stable A/B-test variant assignment on top of `RemoteConfigService`'s
/// flat key/value remote config — that service has no notion of "always
/// put this same player in the same bucket for this experiment", which is
/// exactly what a real A/B test needs. Getting this wrong (re-rolling the
/// bucket every session instead of once per device) silently invalidates
/// every measurement an experiment collects.
///
/// The anonymous id backing every bucket assignment is generated once
/// (`dart:math`'s `Random.secure()` — no new dependency) and cached in
/// [StorageService], so [variantFor] returns the same variant for the same
/// [experimentKey] on the same device across every call and every app
/// restart. A different [experimentKey] hashes independently, so two
/// experiments on the same device aren't correlated with each other.
///
/// Composes naturally with `AnalyticsProvider.logEvent` — call it with the
/// returned variant right after [variantFor] to log exposure; this service
/// only decides the bucket, it never logs anything itself.
class ExperimentBucketingService extends GetxService {
  String? _anonymousId;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static ExperimentBucketingService? get maybe =>
      Get.isRegistered<ExperimentBucketingService>()
      ? Get.find<ExperimentBucketingService>()
      : null;

  /// The per-device anonymous id every bucket assignment is derived from.
  /// Generated once and cached — exposed so a caller can attach it to an
  /// exposure-logging event alongside the assigned variant.
  String get anonymousId {
    final cached = _anonymousId;
    if (cached != null) return cached;

    final stored = StorageService.to.getString(StorageKeys.experimentAnonId);
    if (stored != null && stored.isNotEmpty) {
      _anonymousId = stored;
      return stored;
    }

    final generated = _generateAnonymousId();
    _anonymousId = generated;
    // Unbuffered: this identity must be stable starting from its very
    // first read, unlike a hot-path counter where losing the last write on
    // a kill is an acceptable tradeoff.
    StorageService.to.setString(StorageKeys.experimentAnonId, generated);
    return generated;
  }

  // FEAT-93: DebugQaOverlay's "Variant Switcher" tab — when an
  // experimentKey has an entry here, `variantFor` returns it directly
  // instead of the hash-based bucket, so a QA tester can flip variants
  // instantly for every call site without waiting for a fresh
  // `anonymousId`/reinstall. Always empty in a release build.
  final Map<String, String> _debugVariantOverrides = {};

  /// Overrides `variantFor(experimentKey, ...)`'s result to [variant] —
  /// affects EVERY call site reading this experiment, not just the caller
  /// that set it — until cleared with `null`. A no-op outside
  /// `kDebugMode`/`kProfileMode` (same posture as [dlog]). If [variant]
  /// isn't actually in the `variants` list a later `variantFor` call
  /// passes, that call falls back to its normal hash-based bucket instead
  /// of returning a value the caller never offered.
  void debugSetVariantOverride(String experimentKey, String? variant) {
    if (!kDebugMode && !kProfileMode) return;
    if (variant == null) {
      _debugVariantOverrides.remove(experimentKey);
    } else {
      _debugVariantOverrides[experimentKey] = variant;
    }
  }

  /// Returns the same variant from [variants] for the same [experimentKey]
  /// on this device, every time it's called (including across app
  /// restarts, since [anonymousId] is cached). A different [experimentKey]
  /// is hashed independently, so it isn't correlated with this one.
  ///
  /// Throws [ArgumentError] for an empty [experimentKey] or an empty
  /// [variants] list — there's no bucket to assign in either case.
  String variantFor(String experimentKey, List<String> variants) {
    if (experimentKey.trim().isEmpty) {
      throw ArgumentError.value(
        experimentKey,
        'experimentKey',
        'must not be empty',
      );
    }
    if (variants.isEmpty) {
      throw ArgumentError.value(variants, 'variants', 'must not be empty');
    }
    final override = _debugVariantOverrides[experimentKey];
    if (override != null && variants.contains(override)) {
      return override;
    }
    return variants[bucketIndex(anonymousId, experimentKey, variants.length)];
  }

  /// Pure hash-to-bucket-index step [variantFor] is built on, exposed for
  /// tests that need to check the distribution across many synthetic ids
  /// without touching [StorageService]/`Get` for each one.
  static int bucketIndex(
    String anonymousId,
    String experimentKey,
    int variantCount,
  ) => fnv1aHash('$anonymousId:$experimentKey') % variantCount;

  static String _generateAnonymousId() {
    final random = math.Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
