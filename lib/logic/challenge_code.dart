import 'dart:convert';

import '../data/levels.dart';
import 'replay.dart' show kMaxCodeLength;

/// X25: trần độ dài tên người gửi. `senderName` là "phần còn lại của chuỗi"
/// nên trước đây không có giới hạn nào — mã chứa tên vài trăm KB vẫn decode
/// thành công rồi được nhét thẳng vào `Text` widget ở màn nhập mã, làm treo
/// layout. Người chơi thật không đặt tên dài hơn mức này.
const int kMaxSenderNameLength = 32;

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
  if (code.length > kMaxCodeLength) return null;
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
    if (senderName.length > kMaxSenderNameLength) return null;
    return ChallengeCode(
      levelId: levelId,
      score: score,
      senderName: senderName,
    );
  } catch (_) {
    return null;
  }
}

/// I58: seeded challenge codec, separate from the stable I37 `CH:` format.
class ChallengeSeedCode {
  const ChallengeSeedCode({
    required this.levelId,
    required this.seed,
    required this.score,
    required this.senderName,
  });
  final int levelId;
  final int seed;
  final int score;
  final String senderName;
}

const String challengeSeedCodePrefix = 'CS:';

String encodeChallengeSeedCode(ChallengeSeedCode data) {
  final raw = '${data.levelId}|${data.seed}|${data.score}|${data.senderName}';
  return '$challengeSeedCodePrefix${base64Url.encode(utf8.encode(raw))}';
}

ChallengeSeedCode? decodeChallengeSeedCode(String code) {
  if (code.length > kMaxCodeLength) return null;
  final trimmed = code.trim();
  if (!trimmed.startsWith(challengeSeedCodePrefix)) return null;
  try {
    final raw = utf8.decode(
      base64Url.decode(trimmed.substring(challengeSeedCodePrefix.length)),
    );
    final parts = raw.split('|');
    if (parts.length < 4) return null;
    final levelId = int.tryParse(parts[0]);
    final seed = int.tryParse(parts[1]);
    final score = int.tryParse(parts[2]);
    if (levelId == null || levelId < 1 || levelId > kLevelCount) return null;
    if (seed == null || seed < 0 || score == null || score < 0) return null;
    final senderName = parts.sublist(3).join('|');
    if (senderName.length > kMaxSenderNameLength) return null;
    return ChallengeSeedCode(
      levelId: levelId,
      seed: seed,
      score: score,
      senderName: senderName,
    );
  } catch (_) {
    return null;
  }
}
