import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'versioned_json_store.dart';

/// Metadata for one save slot — [SaveSlotManager] never sees or owns the
/// actual player-profile data inside a slot, only bookkeeping about the
/// slot itself.
class SaveSlotMeta {
  const SaveSlotMeta({
    required this.id,
    required this.displayName,
    required this.createdAtMs,
    required this.lastPlayedAtMs,
  });

  final String id;
  final String displayName;
  final int createdAtMs;
  final int lastPlayedAtMs;

  SaveSlotMeta copyWith({String? displayName, int? lastPlayedAtMs}) =>
      SaveSlotMeta(
        id: id,
        displayName: displayName ?? this.displayName,
        createdAtMs: createdAtMs,
        lastPlayedAtMs: lastPlayedAtMs ?? this.lastPlayedAtMs,
      );
}

/// Manages multiple independent save slots (separate characters/profiles)
/// on the same device — the classic "3 save files, pick a character on the
/// home screen" casual/mid-core game pattern.
///
/// Deliberately a THIN coordinator, same posture as
/// `OnboardingCoordinatorService` (IDEA-54) for a completely different
/// domain: this only tracks slot metadata (id/display name/timestamps) and
/// which slot is active, and hands out a namespaced [keyFor] a caller uses
/// with their OWN `VersionedJsonStore` for the actual player-profile JSON.
/// It never defines that schema itself — every game's profile shape is
/// different, and this doesn't replace `VersionedJsonStore` (FEAT-05), it
/// composes with it.
class SaveSlotManager extends GetxService {
  SaveSlotManager({this.maxSlots}) {
    if (maxSlots != null && maxSlots! <= 0) {
      throw ArgumentError.value(maxSlots, 'maxSlots', 'must be greater than 0');
    }
  }

  static const _metaStorageKey = 'save_slot_meta_v1';
  static const _activeSlotStorageKey = 'save_slot_active_id_v1';

  /// ENH-68: caps how many slots [createSlot] will allow — `null` (default)
  /// means unlimited, unchanged from before this existed. Deliberately not
  /// defaulted to a specific number (3? 5?): how many save slots a game
  /// offers is a product decision for the consumer app, not this package.
  final int? maxSlots;

  List<SaveSlotMeta>? _slots;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static SaveSlotManager? get maybe =>
      Get.isRegistered<SaveSlotManager>() ? Get.find<SaveSlotManager>() : null;

  VersionedJsonStore<List<SaveSlotMeta>> get _store =>
      VersionedJsonStore<List<SaveSlotMeta>>(
        storage: StorageService.to,
        key: _metaStorageKey,
        schemaVersion: 1,
        toJson: (value) => {
          'slots': [
            for (final slot in value)
              {
                'id': slot.id,
                'displayName': slot.displayName,
                'createdAtMs': slot.createdAtMs,
                'lastPlayedAtMs': slot.lastPlayedAtMs,
              },
          ],
        },
        fromJson: _parseSlots,
        migrate: (fromVersion, json) => json,
      );

  // Lazily hydrated on first touch, not in a constructor/onInit — avoids
  // depending on StorageService already being Get.put'd before this
  // service is constructed (same reason as every other service here).
  List<SaveSlotMeta> get _slotList {
    if (_slots != null) return _slots!;
    try {
      _slots = _store.load() ?? <SaveSlotMeta>[];
    } catch (_) {
      // Domain fields are untrusted even after the envelope is valid — a
      // corrupt slot list must never prevent the app from booting.
      _slots = <SaveSlotMeta>[];
    }
    return _slots!;
  }

  List<SaveSlotMeta> _parseSlots(Map<String, Object?> json) {
    final raw = json['slots'];
    if (raw is! List) return <SaveSlotMeta>[];
    final result = <SaveSlotMeta>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final displayName = entry['displayName'];
      final createdAtMs = entry['createdAtMs'];
      final lastPlayedAtMs = entry['lastPlayedAtMs'];
      if (id is! String ||
          id.trim().isEmpty ||
          displayName is! String ||
          createdAtMs is! int ||
          createdAtMs < 0 ||
          lastPlayedAtMs is! int ||
          lastPlayedAtMs < 0) {
        continue;
      }
      if (result.any((s) => s.id == id)) continue; // dedupe corrupt dup ids
      result.add(
        SaveSlotMeta(
          id: id,
          displayName: displayName,
          createdAtMs: createdAtMs,
          lastPlayedAtMs: lastPlayedAtMs,
        ),
      );
    }
    return result;
  }

  // Serializes every save behind the currently in-flight one (same
  // BUG-17/BUG-18 pattern as every other service in this file's family) —
  // 2 rapid createSlot/touchSlot/deleteSlot calls racing their disk writes
  // could otherwise let an older, already-superseded snapshot land on disk
  // LAST and silently roll back a change on next restart.
  bool _saving = false;
  bool _saveDirty = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    try {
      await _store.save(_slotList);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent call's save behind a permanently-rejected chain.
    }
  }

  // BUG-45: was `_saving ? _saveChain.then(...) : _runSave(store)` — same
  // race as every other service in this family (see
  // season_event_service.dart's longer comment on this exact method for
  // why the naive "drop `_saving`, chain via `.then()`" fix is ALSO wrong,
  // proven by TDD). Keeps `_saving`, resets it only after a whole pass
  // settles with no new request arriving during it, calling `_runSave()`
  // directly (never through `await`/`.then()`) and rescheduling via
  // `Future.whenComplete`. `_scheduleSave` itself never awaits anything,
  // so its `if (_saving)` check-and-set is atomic.
  void _scheduleSave() {
    if (_saving) {
      _saveDirty = true;
      return;
    }
    _saving = true;
    _runSaveAndReschedule();
  }

  void _runSaveAndReschedule() {
    _saveDirty = false;
    _saveChain = _runSave().whenComplete(() {
      if (_saveDirty) {
        _runSaveAndReschedule();
      } else {
        _saving = false;
      }
    });
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid calls to fully settle instead of guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// `true` if [createSlot] can be called right now without throwing —
  /// always `true` when [maxSlots] is `null` (unlimited). A UI checks this
  /// to decide whether to disable a "Create slot" button, rather than
  /// re-deriving the same `maxSlots == null || ...` null-check itself.
  bool get canCreateSlot => maxSlots == null || _slotList.length < maxSlots!;

  /// Every slot, most-recently-played first — the classic "Continue" UX.
  List<SaveSlotMeta> listSlots() {
    final slots = [..._slotList]
      ..sort((a, b) => b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs));
    return slots;
  }

  /// Creates a new slot with a freshly-generated, guaranteed-unique id
  /// (even across a burst of rapid calls in the same millisecond).
  /// `createdAtMs`/`lastPlayedAtMs` both start at `nowMsClamped()` — the
  /// same anti-clock-rewind clock every time-gated system in this package
  /// uses, never raw `DateTime.now()`.
  SaveSlotMeta createSlot(String displayName) {
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'must not be empty',
      );
    }
    final limit = maxSlots;
    if (limit != null && _slotList.length >= limit) {
      throw StateError('SaveSlotManager already has the max $limit slot(s)');
    }
    final now = nowMsClamped();
    final id = _generateUniqueId(now);
    final slot = SaveSlotMeta(
      id: id,
      displayName: displayName,
      createdAtMs: now,
      lastPlayedAtMs: now,
    );
    _slotList.add(slot);
    _scheduleSave();
    return slot;
  }

  // Increments the NUMBER on collision rather than appending a `_N` suffix
  // to the same base — a suffix like 'slot_100_1' would itself start with
  // 'slot_100_', which is exactly the prefix `deleteSlot` uses to erase
  // 'slot_100's keys via `removeAllWithPrefix`. That would delete the
  // OTHER slot's data too the moment 2 slots are created in the same
  // millisecond (`_generateUniqueId` gets called back-to-back faster than
  // the clock ticks). Plain incrementing digits never has this problem:
  // 'slot_100_' is never a prefix of 'slot_101_...' or 'slot_1001_...'.
  String _generateUniqueId(int now) {
    var candidate = now;
    while (_slotList.any((s) => s.id == 'slot_$candidate')) {
      candidate++;
    }
    return 'slot_$candidate';
  }

  /// Registers/updates [meta] directly in the slot list — BUG-41: used by
  /// disaster-recovery restore (`DisasterRecoverySaveExport.applyRestore`)
  /// right after it restores a slot's actual data via
  /// `StorageService.importWithPrefix`, which only writes the slot's
  /// namespaced keys and never touches this manager's own separate
  /// `_metaStorageKey` list — without this, the restored data exists on
  /// disk but [listSlots] never surfaces it (an orphaned slot).
  ///
  /// Unlike [createSlot], this is exempt from [maxSlots] (recovering data
  /// that already existed is never capacity-limited) and is idempotent: a
  /// slot already present with the same [SaveSlotMeta.id] is REPLACED by
  /// [meta], never duplicated — covers restoring a backup over a slot
  /// that's still there.
  void restoreSlotMeta(SaveSlotMeta meta) {
    final index = _indexOf(meta.id);
    if (index == -1) {
      _slotList.add(meta);
    } else {
      _slotList[index] = meta;
    }
    _scheduleSave();
  }

  int _indexOf(String id) => _slotList.indexWhere((s) => s.id == id);

  void _validateExists(String id) {
    if (_indexOf(id) == -1) {
      throw ArgumentError.value(id, 'id', 'no such slot');
    }
  }

  /// Renames slot [id]. Throws `ArgumentError` if [id] doesn't exist.
  void renameSlot(String id, String newDisplayName) {
    _validateExists(id);
    if (newDisplayName.trim().isEmpty) {
      throw ArgumentError.value(
        newDisplayName,
        'newDisplayName',
        'must not be empty',
      );
    }
    final index = _indexOf(id);
    _slotList[index] = _slotList[index].copyWith(displayName: newDisplayName);
    _scheduleSave();
  }

  /// Bumps slot [id]'s `lastPlayedAtMs` to now — call when a play session
  /// in that slot starts, so [listSlots] surfaces it first next time.
  /// Throws `ArgumentError` if [id] doesn't exist.
  void touchSlot(String id) {
    _validateExists(id);
    final index = _indexOf(id);
    _slotList[index] = _slotList[index].copyWith(
      lastPlayedAtMs: nowMsClamped(),
    );
    _scheduleSave();
  }

  /// The currently active slot id, or `null` if none has been set yet.
  /// Persists across restart. Reads straight through to [StorageService]
  /// rather than caching a copy here — it's a single plain key, not the
  /// burst-write-prone slot LIST, so there's no race to guard against and
  /// no reason to duplicate state `StorageService` already holds.
  String? get activeSlotId =>
      StorageService.to.getString(_activeSlotStorageKey);

  /// Marks [id] as the active slot. Throws `ArgumentError` (without
  /// changing [activeSlotId]) if [id] doesn't exist — never actives into a
  /// slot that was never created (or was already deleted).
  Future<void> setActiveSlot(String id) {
    _validateExists(id);
    return StorageService.to.setString(_activeSlotStorageKey, id);
  }

  /// A key namespaced to [slotId] for [suffix] — hand this to a
  /// `VersionedJsonStore`'s own `key:` for that slot's player-profile data.
  /// Stable/deterministic (same inputs always produce the same key). Every
  /// [slotId] is always one this class generated itself via
  /// [_generateUniqueId] (`slot_<digits>`, never containing an
  /// underscore-delimited component that could extend another id's own
  /// prefix — see that method's own doc for why that property matters for
  /// [deleteSlot]'s `removeAllWithPrefix` call), so 2 different
  /// `slotId`/`suffix` pairs can never collide.
  String keyFor(String slotId, String suffix) => 'slot_${slotId}_$suffix';

  /// Deletes slot [id]: removes its metadata AND every key namespaced to
  /// it via [keyFor] (through `StorageService.removeAllWithPrefix`) — no
  /// leftover keys from a deleted slot. If [id] was the [activeSlotId],
  /// that becomes `null` afterward (never left pointing at a slot that no
  /// longer exists). Throws `ArgumentError` if [id] doesn't exist.
  Future<void> deleteSlot(String id) async {
    _validateExists(id);
    _slotList.removeWhere((s) => s.id == id);
    _scheduleSave();
    await StorageService.to.removeAllWithPrefix('slot_${id}_');
    if (activeSlotId == id) {
      await StorageService.to.remove(_activeSlotStorageKey);
    }
  }
}
