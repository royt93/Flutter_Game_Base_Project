import 'dart:convert';

import '../data/levels.dart';

/// I37: mã "thách đấu" — chỉ mang levelId + điểm cần vượt + tên người gửi,
/// KHÔNG kèm replay đầy đủ (khác `ReplayData`/`encodeReplay` ở `replay.dart`
/// — payload/mục đích khác hẳn nên không tái dùng chung 1 class). Người nhận
/// tự chơi lại đúng level đó (board random bình thường) rồi so điểm.
class ChallengeCode {
  final int levelId;
  final int score;
  final String senderName;

  const ChallengeCode({
    required this.levelId,
    required this.score,
    required this.senderName,
  });
}

/// Prefix rõ (không mã hoá) để 1 ô nhập mã chung phân biệt được mã thách đấu
/// với mã ghost-replay (`encodeReplay`) — không cần escape `senderName` vì
/// nó luôn là field cuối, xem [decodeChallengeCode].
const String challengeCodePrefix = 'CH:';

/// Mã hoá base64url của `levelId|score|senderName`, có prefix [challengeCodePrefix].
String encodeChallengeCode(ChallengeCode data) {
  final raw = '${data.levelId}|${data.score}|${data.senderName}';
  return '$challengeCodePrefix${base64Url.encode(utf8.encode(raw))}';
}

/// Giải mã ngược [encodeChallengeCode]. Trả `null` nếu thiếu prefix, sai định
/// dạng base64/thiếu cột, số âm, hoặc `levelId` ngoài `1..kLevelCount`.
/// `senderName` là phần còn lại sau cột thứ 2 (không split hết theo `|`) nên
/// giữ nguyên mọi ký tự `|` gốc trong tên — không cần escape khi encode.
ChallengeCode? decodeChallengeCode(String code) {
  final trimmed = code.trim();
  if (!trimmed.startsWith(challengeCodePrefix)) return null;
  try {
    final raw = utf8.decode(
      base64Url.decode(trimmed.substring(challengeCodePrefix.length)),
    );
    final firstBar = raw.indexOf('|');
    if (firstBar < 0) return null;
    final secondBar = raw.indexOf('|', firstBar + 1);
    if (secondBar < 0) return null;
    final levelId = int.tryParse(raw.substring(0, firstBar));
    final score = int.tryParse(raw.substring(firstBar + 1, secondBar));
    final senderName = raw.substring(secondBar + 1);
    if (levelId == null || levelId < 1 || levelId > kLevelCount) return null;
    if (score == null || score < 0) return null;
    return ChallengeCode(
      levelId: levelId,
      score: score,
      senderName: senderName,
    );
  } catch (_) {
    return null;
  }
}
