import 'dart:collection';

import 'package:get/get.dart';

import 'utils/sdk_result.dart';

/// Which loader path an item needs — the coordinator itself never touches
/// Flame/audio/Flutter asset APIs directly; a consumer's injected
/// [AssetLoaderFn] dispatches on this.
enum AssetKind { image, audio, flutterAsset, shader }

/// One entry in a scene's asset manifest.
class AssetManifestItem {
  const AssetManifestItem({
    required this.id,
    required this.kind,
    required this.path,
    this.dependsOn = const [],
    this.required = true,
    this.weight = 1.0,
  }) : assert(weight > 0, 'weight must be > 0');

  final String id;
  final AssetKind kind;
  final String path;

  /// Other item ids in the same manifest that must finish loading first.
  final List<String> dependsOn;

  /// A failed required item fails the whole [AssetPreloadCoordinator.preload]
  /// call (and blocks anything depending on it); a failed optional item is
  /// simply skipped — the scene proceeds without it.
  final bool required;

  /// Relative share of the overall progress bar this item represents.
  final double weight;
}

typedef AssetLoaderFn = Future<void> Function(AssetManifestItem item);
typedef AssetUnloaderFn = void Function(AssetManifestItem item);

/// Preloads a scene's assets against a typed, dependency-aware manifest —
/// no concrete Flame/audio/Flutter-asset/shader API baked in; a consuming
/// app injects [loader] (dispatching on [AssetManifestItem.kind]) and
/// optionally [unloader].
///
/// **Cache**: an item id already loaded by a previous [preload] call is
/// never loaded twice — [loader] is only invoked the first time a given id
/// is needed, and every subsequent [preload]/[unloadScene] call for that
/// id just adjusts a reference count. Only once that count reaches 0 does
/// [unloadScene] call [unloader] — a shared asset shared across 2 scenes
/// survives unloading either scene alone.
///
/// **Dependency graph**: [AssetManifestItem.dependsOn] referencing an id
/// not present in the manifest, or a dependency cycle, is caught by
/// [preload] up front — a typed [SdkFailure] before any loader call runs,
/// never a runtime crash mid-load.
///
/// **Bounded concurrency**: items whose dependencies are already satisfied
/// load in parallel, capped at [maxConcurrent] in flight at once; a later
/// wave only starts once its dependencies finish.
///
/// **Progress** ([progress], 0.0–1.0) only advances when an item finishes
/// in a way that lets the scene proceed with it — a successful load, or an
/// optional item's failure. A required item's failure (and everything that
/// transitively depends on it) never contributes, so [progress] can never
/// reach 1.0 while a required asset is missing — a caller must inspect the
/// returned [SdkResult] instead of waiting for `progress == 1.0` to decide
/// a scene is ready.
///
/// **Cancel/retry**: [cancel] stops starting new waves — everything already
/// in flight is still awaited to completion (never abandoned, so nothing
/// leaks), only items that hadn't started yet are left unprocessed.
/// [retryFailed] re-runs [preload] against the last manifest — already-
/// cached items are skipped again via the same cache, so only the
/// previously-failed (and anything they blocked) actually re-attempts.
class AssetPreloadCoordinator extends GetxService {
  AssetPreloadCoordinator({
    required this.loader,
    this.unloader,
    this.maxConcurrent = 4,
  }) : assert(maxConcurrent >= 1, 'maxConcurrent must be >= 1');

  final AssetLoaderFn loader;
  final AssetUnloaderFn? unloader;
  final int maxConcurrent;

  static AssetPreloadCoordinator? get maybe =>
      Get.isRegistered<AssetPreloadCoordinator>()
      ? Get.find<AssetPreloadCoordinator>()
      : null;

  final progress = 0.0.obs;

  final _refCounts = <String, int>{};
  final _loadedIds = <String>{};
  final _failedIds = <String>{};
  List<AssetManifestItem> _lastManifest = const [];
  bool _cancelRequested = false;

  bool isLoaded(String id) => _loadedIds.contains(id);

  Future<SdkResult<void>> preload(List<AssetManifestItem> manifest) async {
    _lastManifest = manifest;
    _cancelRequested = false;
    progress.value = 0.0;

    final validationError = _validate(manifest);
    if (validationError != null) return validationError;

    if (manifest.isEmpty) {
      progress.value = 1.0;
      return const SdkSuccess(null);
    }

    final byId = {for (final item in manifest) item.id: item};
    final blocked = <String>{};
    final processed = <String>{};
    final totalWeight = manifest.fold<double>(0, (sum, i) => sum + i.weight);
    var doneWeight = 0.0;

    final ready = Queue<String>()
      ..addAll(manifest.where((i) => i.dependsOn.isEmpty).map((i) => i.id));

    while (ready.isNotEmpty && !_cancelRequested) {
      final batch = <String>[];
      while (ready.isNotEmpty && batch.length < maxConcurrent) {
        batch.add(ready.removeFirst());
      }

      await Future.wait(
        batch.map((id) async {
          final item = byId[id]!;
          processed.add(id);

          bool ok;
          if (blocked.contains(id)) {
            ok = false;
            _failedIds.add(id);
          } else if (_loadedIds.contains(id)) {
            ok = true;
          } else {
            try {
              await loader(item);
              _loadedIds.add(id);
              _failedIds.remove(id);
              ok = true;
            } catch (_) {
              _failedIds.add(id);
              ok = false;
            }
          }

          if (ok) {
            _refCounts[id] = (_refCounts[id] ?? 0) + 1;
          }
          if (ok || !item.required) {
            doneWeight += item.weight;
          }
          if (!ok && item.required) {
            for (final other in manifest) {
              if (other.dependsOn.contains(id)) blocked.add(other.id);
            }
          }
        }),
      );

      progress.value = totalWeight == 0 ? 1.0 : doneWeight / totalWeight;

      for (final item in manifest) {
        if (processed.contains(item.id) || ready.contains(item.id)) continue;
        if (item.dependsOn.every(processed.contains)) {
          ready.add(item.id);
        }
      }
    }

    if (_cancelRequested) {
      return const SdkFailure(
        kind: SdkErrorKind.unknown,
        message: 'Asset preload cancelled',
        retryable: true,
      );
    }

    final requiredFailedIds = [
      for (final item in manifest)
        if (item.required &&
            (_failedIds.contains(item.id) || blocked.contains(item.id)))
          item.id,
    ];
    if (requiredFailedIds.isNotEmpty) {
      return SdkFailure(
        kind: SdkErrorKind.unknown,
        message:
            'Required asset(s) failed to load: ${requiredFailedIds.join(', ')}',
        retryable: true,
      );
    }
    return const SdkSuccess(null);
  }

  /// Stops starting new waves — anything already loading finishes normally
  /// (never abandoned), items that hadn't started stay unprocessed.
  void cancel() => _cancelRequested = true;

  Future<SdkResult<void>> retryFailed() => preload(_lastManifest);

  /// Decrements the reference count of every item in the last [preload]d
  /// manifest, calling [unloader] only for the ones that reach 0 — a
  /// still-referenced-elsewhere asset survives.
  void unloadScene() {
    for (final item in _lastManifest) {
      final current = _refCounts[item.id];
      if (current == null) continue;
      final next = current - 1;
      if (next <= 0) {
        _refCounts.remove(item.id);
        _loadedIds.remove(item.id);
        unloader?.call(item);
      } else {
        _refCounts[item.id] = next;
      }
    }
  }

  SdkFailure<void>? _validate(List<AssetManifestItem> manifest) {
    final ids = manifest.map((i) => i.id).toSet();
    for (final item in manifest) {
      for (final dep in item.dependsOn) {
        if (!ids.contains(dep)) {
          return SdkFailure(
            kind: SdkErrorKind.validation,
            message: 'Asset "${item.id}" depends on missing asset "$dep"',
          );
        }
      }
    }

    final byId = {for (final item in manifest) item.id: item};
    final color = <String, int>{};
    bool hasCycle(String id) {
      color[id] = 1;
      for (final dep in byId[id]!.dependsOn) {
        final depColor = color[dep] ?? 0;
        if (depColor == 1) return true;
        if (depColor == 0 && hasCycle(dep)) return true;
      }
      color[id] = 2;
      return false;
    }

    for (final item in manifest) {
      if ((color[item.id] ?? 0) == 0 && hasCycle(item.id)) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Asset manifest has a dependency cycle',
        );
      }
    }
    return null;
  }
}
