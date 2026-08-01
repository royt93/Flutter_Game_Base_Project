import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const secureBackupCodePrefix = 'BK2:';
const secureBackupCodeVersion = 1;

final _backupCipher = AesGcm.with256bits();

// Transparent encryption: works across devices without user input. This is
// protection against casual inspection/tampering, not a user-secret vault.
final _backupKey = SecretKeyData([
  0x4e,
  0x65,
  0x6f,
  0x6e,
  0x53,
  0x74,
  0x61,
  0x72,
  0x42,
  0x61,
  0x63,
  0x6b,
  0x75,
  0x70,
  0x4b,
  0x65,
  0x79,
  0x32,
  0x30,
  0x32,
  0x36,
  0x42,
  0x4b,
  0x32,
  0x41,
  0x45,
  0x53,
  0x47,
  0x43,
  0x4d,
  0x21,
  0x7f,
]);

String _encodePart(List<int> bytes) => base64Url.encode(bytes);

List<int> _decodePart(String value) => base64Url.decode(value);

/// Encodes a tamper-evident, automatically encrypted backup code.
Future<String> encodeSecureBackupCode(Map<String, Object> data) async {
  final box = await _backupCipher.encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: _backupKey,
  );
  return '$secureBackupCodePrefix$secureBackupCodeVersion.${box.nonce.length}.'
      '${_encodePart(box.nonce)}.${_encodePart(box.cipherText)}.'
      '${_encodePart(box.mac.bytes)}';
}

/// Decodes the current version and the original unversioned BK2 format.
Future<Map<String, Object>?> decodeSecureBackupCode(String code) async {
  final trimmed = code.trim();
  if (!trimmed.startsWith(secureBackupCodePrefix)) return null;
  try {
    final parts = trimmed.substring(secureBackupCodePrefix.length).split('.');
    late final int nonceLength;
    late final String noncePart;
    late final String cipherTextPart;
    late final String macPart;
    if (parts.length == 5) {
      if (int.parse(parts[0]) != secureBackupCodeVersion) return null;
      nonceLength = int.parse(parts[1]);
      noncePart = parts[2];
      cipherTextPart = parts[3];
      macPart = parts[4];
    } else if (parts.length == 4) {
      // Backward compatibility for codes generated before versioning.
      if (int.parse(parts[0]) != 12) return null;
      nonceLength = int.parse(parts[0]);
      noncePart = parts[1];
      cipherTextPart = parts[2];
      macPart = parts[3];
    } else {
      return null;
    }
    if (nonceLength != 12) return null;
    final box = SecretBox(
      _decodePart(cipherTextPart),
      nonce: _decodePart(noncePart),
      mac: Mac(_decodePart(macPart)),
    );
    final raw = await _backupCipher.decrypt(box, secretKey: _backupKey);
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map) return null;
    return Map<String, Object>.from(decoded);
  } catch (_) {
    return null;
  }
}
