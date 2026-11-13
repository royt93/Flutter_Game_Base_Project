import 'package:flutter/foundation.dart' show VoidCallback;

import '../storage_service.dart';

/// For a service that caches state read lazily from [StorageService]: calls
/// [onReplaced] after a bulk replace (`importAll`, `eraseAll`,
/// `importWithPrefix`, `removeAllWithPrefix`) so the cache is dropped instead of
/// being written back over the restored or erased data (BUG-117).
///
/// Attach with [watchStorageReplace] the first time the cache is filled (the
/// storage service may not exist before that), and detach in `onClose` with
/// [stopWatchingStorageReplace].
mixin StorageReplaceWatch {
  StorageService? _watched;
  VoidCallback? _onReplaced;

  void watchStorageReplace(StorageService storage, VoidCallback onReplaced) {
    if (identical(_watched, storage)) return;
    stopWatchingStorageReplace();
    _watched = storage;
    _onReplaced = onReplaced;
    storage.replaceEpoch.addListener(onReplaced);
  }

  void stopWatchingStorageReplace() {
    final storage = _watched;
    final callback = _onReplaced;
    if (storage != null && callback != null) {
      storage.replaceEpoch.removeListener(callback);
    }
    _watched = null;
    _onReplaced = null;
  }
}
