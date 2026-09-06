import 'dart:convert';

import 'package:crypto/crypto.dart';

/// HMAC checksum layer sitting on top of [StorageService]'s
/// `exportAll()`/`importAll()` — sign a save file on export, verify it on
/// import, so a consuming game can detect a save that was hand-edited
/// (e.g. someone bumped their coin count with an external tool).
///
/// **What this defends against:** casual save editing — opening the
/// exported JSON in a text editor / hex editor / save-editor app and
/// changing a value, then feeding it back through `importAll`. Any such
/// edit changes the HMAC, which `verifyAndStrip` catches before the data
/// ever reaches `importAll`.
///
/// **What this does NOT defend against:** a determined attacker who
/// extracts the app binary and recovers [String] secret passed here. This
/// is a client-side, best-effort deterrent ("chống gian lận local-first"),
/// not a substitute for server-side validation — same honest framing as
/// `lib/core/utils/clamped_clock.dart`. That's why the secret is supplied
/// by the consuming app rather than baked into this package: a secret
/// shared by every game built on this kit would leak the moment anyone
/// decompiles a single one of them.
const String checksumKey = '_checksum';

/// Deterministic serialization: sort keys first so the same data always
/// produces the same bytes regardless of map insertion/iteration order.
String _canonicalize(Map<String, Object?> data) {
  final sortedKeys = data.keys.toList()..sort();
  final ordered = {for (final k in sortedKeys) k: data[k]};
  return jsonEncode(ordered);
}

String _hmac(Map<String, Object?> data, String secret) {
  final mac = Hmac(sha256, utf8.encode(secret));
  return mac.convert(utf8.encode(_canonicalize(data))).toString();
}

/// Signs [data] (the output of `StorageService.exportAll()`) with an
/// HMAC-SHA256 keyed by [secret], returning a new map equal to [data] plus
/// one reserved [checksumKey] entry holding the hex-encoded digest.
Map<String, Object?> signExport(Map<String, Object?> data, String secret) {
  return {...data, checksumKey: _hmac(data, secret)};
}

/// Verifies a map produced by [signExport] and, if the checksum matches,
/// returns the original data with [checksumKey] removed — ready to pass
/// straight into `StorageService.importAll()`.
///
/// Throws a [FormatException] if [checksumKey] is missing, or if the
/// recomputed HMAC doesn't match (tampered/corrupted data). Callers should
/// catch this and warn the player / refuse to import rather than silently
/// importing unverified data.
Map<String, Object?> verifyAndStrip(
  Map<String, Object?> signed,
  String secret,
) {
  if (!signed.containsKey(checksumKey)) {
    throw const FormatException(
      'Save file thiếu checksum — không thể xác minh tính toàn vẹn dữ liệu.',
    );
  }
  final storedChecksum = signed[checksumKey];
  final data = Map<String, Object?>.from(signed)..remove(checksumKey);
  if (_hmac(data, secret) != storedChecksum) {
    throw const FormatException(
      'Save file đã bị chỉnh sửa hoặc hỏng — checksum không khớp.',
    );
  }
  return data;
}
