import 'package:flutter/foundation.dart' show VoidCallback;

import '../storage_service.dart';

/// For a service that caches state read lazily from [StorageService]: calls
/// [onReplaced] after the store was replaced behind its back, so the cache is
/// dropped instead of being written back over the restored or erased data
/// (BUG-117).
///
/// Two signals trigger it:
/// - a whole-store replace (`importAll`, `eraseAll`): always;
/// - a prefix replace (`importWithPrefix`, `removeAllWithPrefix`): only when
///   the service's own storage key is under the replaced prefix, because such
///   an operation never touches any other key (BUG-81), and
///   `SaveSlotManager.deleteSlot` itself triggers one while its in-memory slot
///   list is still correct.
///
/// Attach with [watchStorageReplace] the first time the cache is filled (the
/// storage service may not exist before that), and detach in `onClose` with
/// [stopWatchingStorageReplace].
mixin StorageReplaceWatch {
  StorageService? _watched;
  VoidCallback? _onWhole;
  VoidCallback? _onPrefix;

  void watchStorageReplace(
    StorageService storage,
    String storageKey,
    VoidCallback onReplaced,
  ) {
    if (identical(_watched, storage)) return;
    stopWatchingStorageReplace();
    _watched = storage;
    _onWhole = onReplaced;
    _onPrefix = () {
      final change = storage.prefixReplace.value;
      if (change != null && change.covers(storageKey)) onReplaced();
    };
    storage.replaceEpoch.addListener(_onWhole!);
    storage.prefixReplace.addListener(_onPrefix!);
  }

  void stopWatchingStorageReplace() {
    final storage = _watched;
    if (storage != null) {
      if (_onWhole != null) storage.replaceEpoch.removeListener(_onWhole!);
      if (_onPrefix != null) storage.prefixReplace.removeListener(_onPrefix!);
    }
    _watched = null;
    _onWhole = null;
    _onPrefix = null;
  }
}
