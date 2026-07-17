import 'dart:convert';

/// I26 (task #18): mã "so tài" chứa tên + tổng sao + xu của 1 người chơi,
/// dùng để chia sẻ qua [shareText] (`share_helper.dart`) rồi bạn bè dán mã
/// vào màn so sánh — không backend, không định danh thật, chỉ text mã hoá.
class FriendCodeData {
  final String name;
  final int totalStars;
  final int coins;

  const FriendCodeData({
    required this.name,
    required this.totalStars,
    required this.coins,
  });
}

/// Mã hoá base64url của `name|totalStars|coins`. [name] bị lọc bỏ ký tự `|`
/// (delimiter) để decode không lệch cột.
String encodeFriendCode({
  required String name,
  required int totalStars,
  required int coins,
}) {
  final safeName = name.replaceAll('|', ' ').trim();
  final raw = '$safeName|$totalStars|$coins';
  return base64Url.encode(utf8.encode(raw));
}

/// Giải mã ngược [encodeFriendCode]. Trả `null` nếu mã sai định dạng, thiếu
/// cột, hoặc số âm — không throw để callsite chỉ cần check null.
FriendCodeData? decodeFriendCode(String code) {
  try {
    final raw = utf8.decode(base64Url.decode(code.trim()));
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final name = parts[0].trim();
    if (name.isEmpty) return null;
    final stars = int.tryParse(parts[1]);
    final coins = int.tryParse(parts[2]);
    if (stars == null || coins == null || stars < 0 || coins < 0) {
      return null;
    }
    return FriendCodeData(name: name, totalStars: stars, coins: coins);
  } catch (_) {
    return null;
  }
}
