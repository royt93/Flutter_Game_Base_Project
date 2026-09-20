import 'dart:convert';

import 'save_integrity.dart';
import 'save_slot_manager.dart';
import 'storage_service.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// One save slot's exported data — [meta] mirrors [SaveSlotMeta] (plain
/// fields, this class never holds a live reference to it), [data] is the
/// raw `StorageService.exportWithPrefix` result for that slot's key
/// range.
class SlotExportEntry {
  const SlotExportEntry({required this.meta, required this.data});

  final SaveSlotMeta meta;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'meta': {
      'id': meta.id,
      'displayName': meta.displayName,
      'createdAtMs': meta.createdAtMs,
      'lastPlayedAtMs': meta.lastPlayedAtMs,
    },
    'data': data,
  };

  /// Returns `null` (never throws) on a malformed entry — same
  /// defensive convention `ReplayCapsule.fromJsonUnsigned` and
  /// `AssetLicenseEntry.fromJson` already use for hand-editable JSON.
  static SlotExportEntry? fromJson(Map<String, Object?> json) {
    final rawMeta = json['meta'];
    final rawData = json['data'];
    if (rawMeta is! Map || rawData is! Map) return null;
    final id = rawMeta['id'];
    final displayName = rawMeta['displayName'];
    final createdAtMs = rawMeta['createdAtMs'];
    final lastPlayedAtMs = rawMeta['lastPlayedAtMs'];
    if (id is! String ||
        id.trim().isEmpty ||
        displayName is! String ||
        createdAtMs is! int ||
        lastPlayedAtMs is! int) {
      return null;
    }
    return SlotExportEntry(
      meta: SaveSlotMeta(
        id: id,
        displayName: displayName,
        createdAtMs: createdAtMs,
        lastPlayedAtMs: lastPlayedAtMs,
      ),
      data: Map<String, Object?>.from(rawData),
    );
  }
}

/// A validated, NOT-YET-APPLIED export — [DisasterRecoverySaveExport.previewRestore]
/// returns this so a UI/support agent can review exactly what a backup
/// contains (slot names, when each was last played, how many keys) before
/// [DisasterRecoverySaveExport.applyRestore] ever touches real storage.
/// Building this never writes anything — see that method's own doc.
class RestorePreview {
  const RestorePreview({
    required this.entries,
    required this.generatedAtMs,
    required this.appVersion,
  });

  final List<SlotExportEntry> entries;
  final int generatedAtMs;
  final String appVersion;
}

/// One step of an [DisasterRecoverySaveExport.applyRestore] run — the
/// recovery log a crash/interruption mid-restore leaves behind, so
/// "which slots actually got restored before it broke" is answerable
/// afterward instead of guessed.
class RestoreLogEntry {
  const RestoreLogEntry({
    required this.slotId,
    required this.succeeded,
    required this.atMs,
    required this.detail,
  });

  final String slotId;
  final bool succeeded;
  final int atMs;
  final String detail;

  @override
  String toString() => '[${succeeded ? 'ok' : 'FAILED'}] $slotId: $detail';
}

/// Multi-slot disaster-recovery export/restore, composing 3 already-
/// shipped primitives rather than inventing new ones:
/// [SaveSlotManager] (which slots exist, and [SaveSlotManager.keyFor]'s
/// per-slot key prefix), [StorageService.exportWithPrefix]/
/// [StorageService.importWithPrefix] (the actual data movement — whose
/// existing rollback-on-failure guarantee, see `storage_service.dart`'s
/// `importAll`, is exactly what makes [applyRestore] crash-safe: a
/// `SharedPreferences` write has no transaction primitive, so
/// `importAll` snapshots the WHOLE store first and re-applies that
/// snapshot if the replace throws, meaning a slot that never got reached
/// keeps its pre-restore data, and a slot whose own import failed
/// mid-way rolls back to what IT had before that one call, not a
/// half-written mix), and `save_integrity.dart`'s HMAC sign/verify (the
/// same convention `ReplayCapsule.exportSigned` already uses).
class DisasterRecoverySaveExport {
  DisasterRecoverySaveExport({
    required this.storage,
    required this.slotManager,
    this.maxBytes = defaultMaxBytes,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int schemaVersion = 1;

  /// 2 MB — generous for `SharedPreferences`-backed save data (which is
  /// itself practically bounded by the platform's own prefs-file size
  /// limits), small enough that an export can't itself become an
  /// unbounded-size bug.
  static const int defaultMaxBytes = 2 * 1024 * 1024;

  final StorageService storage;
  final SaveSlotManager slotManager;
  final int maxBytes;
  final int Function() _nowMs;

  final List<RestoreLogEntry> _recoveryLog = [];

  /// Every [applyRestore] step ever run, oldest first — never cleared
  /// automatically (a disaster-recovery audit trail should outlive any
  /// one restore attempt).
  List<RestoreLogEntry> get recoveryLog => List.unmodifiable(_recoveryLog);

  /// Builds an unsigned export bundle for [slotIds] — `SdkFailure` (kind
  /// `validation`) if any id doesn't exist, or if the assembled JSON
  /// exceeds [maxBytes]. Unlike `DiagnosticsExportBundle` (FEAT-70),
  /// which drops sections to fit under its cap, a save export that's too
  /// big is rejected WHOLESALE — a partially-included slot's save data is
  /// actively worse than no export at all (a restore built from it would
  /// look complete but silently lose progress).
  SdkResult<Map<String, Object?>> buildExport({
    required List<String> slotIds,
    required String appVersion,
  }) {
    final byId = {for (final s in slotManager.listSlots()) s.id: s};
    final entries = <SlotExportEntry>[];
    for (final id in slotIds) {
      final meta = byId[id];
      if (meta == null) {
        return SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Slot "$id" không tồn tại',
        );
      }
      entries.add(
        SlotExportEntry(
          meta: meta,
          data: storage.exportWithPrefix(slotManager.keyFor(id, '')),
        ),
      );
    }

    final bundle = {
      'schemaVersion': schemaVersion,
      'generatedAtMs': _nowMs(),
      'appVersion': appVersion,
      'slots': [for (final e in entries) e.toJson()],
    };

    final size = utf8.encode(jsonEncode(bundle)).length;
    if (size > maxBytes) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'Export vượt size cap ($size > $maxBytes byte) — giảm số slot chọn export',
      );
    }
    return SdkSuccess(bundle);
  }

  /// Signs [bundle] (the map [buildExport] returned) — `save_integrity.dart`'s
  /// own `signExport`, same convention `ReplayCapsule.exportSigned`
  /// already uses.
  Map<String, Object?> sign(Map<String, Object?> bundle, String secret) =>
      signExport(bundle, secret);

  /// Verifies + validates a signed export WITHOUT applying anything —
  /// no [storage] write happens anywhere in this method, on any path,
  /// success or failure. `SdkFailure` (kind `validation`) on a bad
  /// checksum (tampered/corrupt), an unsupported `schemaVersion` (newer
  /// than this class's own — same "never guess how to read a future
  /// shape" discipline `VersionedJsonStore`/`RemoteContentPack` already
  /// use), or a malformed `slots` entry.
  SdkResult<RestorePreview> previewRestore(
    Map<String, Object?> signedBundle,
    String secret,
  ) {
    final Map<String, Object?> bundle;
    try {
      bundle = verifyAndStrip(signedBundle, secret);
    } on FormatException catch (error) {
      return SdkFailure(kind: SdkErrorKind.validation, message: error.message);
    }

    final version = bundle['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'schemaVersion không được hỗ trợ (${bundle['schemaVersion']})',
      );
    }

    final rawSlots = bundle['slots'];
    if (rawSlots is! List) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Bundle thiếu field "slots"',
      );
    }

    final entries = <SlotExportEntry>[];
    for (final raw in rawSlots) {
      if (raw is! Map) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Có entry trong "slots" không phải object hợp lệ',
        );
      }
      final entry = SlotExportEntry.fromJson(Map<String, Object?>.from(raw));
      if (entry == null) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Có slot entry thiếu field bắt buộc hoặc sai type',
        );
      }
      entries.add(entry);
    }

    return SdkSuccess(
      RestorePreview(
        entries: entries,
        generatedAtMs: asIntOr(bundle['generatedAtMs'], 0),
        appVersion: asStringOr(bundle['appVersion'], ''),
      ),
    );
  }

  /// Applies an already-[previewRestore]-validated [preview] — restores
  /// slot-by-slot via `StorageService.importWithPrefix`, in order,
  /// STOPPING at the first failure rather than continuing past it: each
  /// step is logged to [recoveryLog] (success or failure with a reason),
  /// so an interruption's exact stopping point is always answerable
  /// afterward. Slots already restored before a failure keep their new
  /// (restored) data; slots never reached keep whatever they had before
  /// this call — a crash never leaves a half-written slot, because
  /// `importWithPrefix`'s own underlying `importAll` rolls back to its
  /// own pre-call snapshot on any exception (see this class's own doc
  /// comment).
  Future<SdkResult<void>> applyRestore(RestorePreview preview) async {
    for (final entry in preview.entries) {
      try {
        await storage.importWithPrefix(
          slotManager.keyFor(entry.meta.id, ''),
          entry.data,
        );
        _recoveryLog.add(
          RestoreLogEntry(
            slotId: entry.meta.id,
            succeeded: true,
            atMs: _nowMs(),
            detail: 'Đã khôi phục ${entry.data.length} key',
          ),
        );
      } catch (error) {
        _recoveryLog.add(
          RestoreLogEntry(
            slotId: entry.meta.id,
            succeeded: false,
            atMs: _nowMs(),
            detail: error.toString(),
          ),
        );
        return SdkFailure(
          kind: SdkErrorKind.storage,
          message:
              'Restore thất bại ở slot "${entry.meta.id}" — các slot đã '
              'restore trước đó vẫn giữ nguyên, slot này giữ nguyên dữ '
              'liệu cũ (không bị ghi dở dang)',
          cause: error,
        );
      }
    }
    return const SdkSuccess(null);
  }
}
