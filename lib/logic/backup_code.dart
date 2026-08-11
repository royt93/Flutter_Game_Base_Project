import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// X25: trần độ dài mã backup. Save đầy đủ (~97 key, phần lớn là int) mã hoá
/// ra vài KB; 64KB là dư dả cho profile lớn nhất mà vẫn chặn payload hàng MB
/// bắt `AesGcm.decrypt` chạy trên UI isolate. Rộng hơn [kMaxCodeLength] của
/// các codec khác vì backup thật sự mang nhiều dữ liệu, không phải 1 bàn cờ.
const int kMaxBackupCodeLength = 64 * 1024;

const backupCodePrefix = 'BK2:';
const backupCodeVersion = 1;

final _backupCipher = AesGcm.with256bits();

/// X26 — **mô hình đe doạ, đọc trước khi dựa vào file này.**
///
/// Khoá này là hằng số trong source, nên nó nằm nguyên trong APK/IPA của mọi
/// bản cài. Vì vậy:
///
/// - **CHỐNG được:** mã backup bị sửa nhầm/hỏng khi copy-paste, và người dùng
///   nghịch tay sửa vài ký tự trong mã. AES-GCM phát hiện và [decodeBackupCode]
///   trả `null`.
/// - **KHÔNG chống được:** giả mạo có chủ đích. Ai trích được khoá (dump APK,
///   hoặc chỉ cần đọc file này) đều giải mã được mọi mã backup, sửa
///   coin/level/achievement, mã hoá lại bằng đúng khoá đó, và MAC vẫn hợp lệ.
///
/// Chấp nhận có chủ đích: game không có backend, không IAP, không leaderboard
/// thật (bot tĩnh — xem `*_leaderboard_bots.dart`), nên người chơi giả mạo
/// save của chính mình chỉ tự phá trải nghiệm của mình, không có nạn nhân thứ
/// hai. Đã cân nhắc và bác bỏ khoá-theo-thiết-bị: nó phá đúng lý do backup tồn
/// tại (chuyển save sang máy khác).
///
/// **Bảo vệ thật sự có giá trị ở đây là chịu được payload hỏng/độc**, không
/// phải lớp mã hoá: xem [[X18]] (hydrate không guard làm app không boot được)
/// và [[X25]] ([kMaxBackupCodeLength]).
///
/// **Nếu sau này thêm bất cứ thứ gì có giá trị thật** — leaderboard online,
/// IAP, vật phẩm trao đổi được — file này phải được xem lại trước tiên.
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

/// Đóng gói save thành mã chia sẻ được, có phát hiện hỏng dữ liệu.
///
/// X26: KHÔNG phải "tamper-proof" — xem doc của `_backupKey` ở trên để biết
/// chính xác lớp này chống được gì và không chống được gì.
Future<String> encodeBackupCode(Map<String, Object> data) async {
  final box = await _backupCipher.encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: _backupKey,
  );
  return '$backupCodePrefix$backupCodeVersion.${box.nonce.length}.'
      '${_encodePart(box.nonce)}.${_encodePart(box.cipherText)}.'
      '${_encodePart(box.mac.bytes)}';
}

/// Giải mã ngược [encodeBackupCode], nhận cả định dạng BK2 chưa đánh
/// version. Trả `null` cho mọi mã hỏng/sai định dạng/quá dài — không throw.
///
/// X26: `null` ở đây nghĩa là "mã không đọc được", KHÔNG phải "mã chắc chắn
/// chưa bị ai sửa" — xem doc của `_backupKey`.
Future<Map<String, Object>?> decodeBackupCode(String code) async {
  // X25: chặn trước khi base64-decode và trước khi AES-GCM chạy — cả hai đều
  // cấp phát theo kích thước input, trên UI isolate.
  if (code.length > kMaxBackupCodeLength) return null;
  final trimmed = code.trim();
  if (!trimmed.startsWith(backupCodePrefix)) return null;
  try {
    final parts = trimmed.substring(backupCodePrefix.length).split('.');
    late final int nonceLength;
    late final String noncePart;
    late final String cipherTextPart;
    late final String macPart;
    if (parts.length == 5) {
      if (int.parse(parts[0]) != backupCodeVersion) return null;
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
