import 'dart:convert';

/// I28: dữ liệu 1 lượt chơi ghi lại được — đủ để dựng lại y hệt màn chơi qua
/// `PopStarGame(seed: seed, ...)` rồi tự động tap lại đúng thứ tự [taps].
/// Chỉ ghi được cho `GameMode.campaign` (xem `game_screen_controller.dart`) vì
/// zen/endless không có bàn cố định, dailyChallenge dùng `presetGrid` riêng.
class ReplayData {
  final int levelId;
  final int seed;
  final List<(int, int)> taps;

  const ReplayData({
    required this.levelId,
    required this.seed,
    required this.taps,
  });
}

/// Mã hoá base64url của `levelId|seed|r1,c1;r2,c2;...`.
String encodeReplay(ReplayData data) {
  final tapsRaw = data.taps.map((t) => '${t.$1},${t.$2}').join(';');
  final raw = '${data.levelId}|${data.seed}|$tapsRaw';
  return base64Url.encode(utf8.encode(raw));
}

/// X25: trần độ dài mã, áp ở **mọi** codec nhận input không tin cậy (người
/// chơi dán mã từ bạn bè / QR / internet). Bàn lớn nhất trong game là 14×14
/// (endless) = 196 ô; mã replay dài nhất thực tế ~1KB. 4096 là dư dả cho mọi
/// mã thật mà vẫn chặn payload hàng MB.
const int kMaxCodeLength = 4096;

/// X25: trần số tap trong 1 replay. Bàn không refill (Zen là ngoại lệ và
/// không ghi replay được) nên mỗi tap hợp lệ xoá ≥2 ô — 196 ô ⇒ tối đa ~98
/// tap thật. 512 là dư dả, đồng thời chặn mã chứa hàng trăm nghìn entry
/// `0,0;` làm treo UI isolate khi materialize list và khi phát lại từng tap
/// bằng timer.
const int kMaxReplayTaps = 512;

/// Giải mã ngược [encodeReplay]. Trả `null` nếu mã sai định dạng, thiếu cột,
/// số âm, vượt [kMaxCodeLength]/[kMaxReplayTaps], hoặc 1 tap không đúng định
/// dạng `row,col` — không throw để callsite chỉ cần check null (không phân
/// biệt lỗi cụ thể, mã giả mạo/hỏng đều `null`).
ReplayData? decodeReplay(String code) {
  // Kiểm TRƯỚC khi decode: base64 của 10MB rác vẫn cấp phát 10MB chuỗi rồi
  // mới hỏng, mà lúc đó đã treo rồi.
  if (code.length > kMaxCodeLength) return null;
  try {
    final raw = utf8.decode(base64Url.decode(code.trim()));
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final levelId = int.tryParse(parts[0]);
    final seed = int.tryParse(parts[1]);
    if (levelId == null || seed == null || levelId <= 0) return null;

    final tapsRaw = parts[2];
    final taps = <(int, int)>[];
    if (tapsRaw.isNotEmpty) {
      final entries = tapsRaw.split(';');
      if (entries.length > kMaxReplayTaps) return null;
      for (final entry in entries) {
        final rc = entry.split(',');
        if (rc.length != 2) return null;
        final r = int.tryParse(rc[0]);
        final c = int.tryParse(rc[1]);
        if (r == null || c == null || r < 0 || c < 0) return null;
        taps.add((r, c));
      }
    }

    return ReplayData(levelId: levelId, seed: seed, taps: taps);
  } catch (_) {
    return null;
  }
}

// ===== F16 Ghost Duel =====

/// F16: dữ liệu một lời thách đấu — bàn tất định từ [seed], toàn bộ nước đi
/// của người thách, điểm cuối và tên họ.
///
/// **Vì sao mở rộng `replay.dart` chứ không phải `challenge_code.dart`:**
/// duel cần *danh sách tap*, mà chỉ replay có. `challenge_code` chỉ mang điểm
/// số — thêm taps vào đó là biến nó thành replay lần thứ hai. AC cấm codec thứ
/// ba, nên dùng lại đúng nhà của taps.
///
/// **Vì sao có `seed` mà không có `levelId`:** replay tất định chỉ đúng ở
/// campaign (bàn campaign sinh ngẫu nhiên mỗi lần chơi). Duel phải dùng bàn
/// sinh từ seed như Daily Challenge, nếu không hai người chơi hai bàn khác nhau.
class DuelData {
  const DuelData({
    required this.seed,
    required this.taps,
    required this.score,
    required this.senderName,
  });

  final int seed;
  final List<(int, int)> taps;
  final int score;
  final String senderName;
}

/// Prefix để phân biệt với mã replay trần và mã challenge (`CH:`).
const String duelCodePrefix = 'DU:';

/// Mã hoá `seed|score|taps|senderName`.
///
/// `senderName` là field **cuối** và không split hết theo `|`, nên tên chứa
/// dấu `|` vẫn giữ nguyên — cùng thủ thuật `challenge_code.dart` đang dùng.
String encodeDuelCode(DuelData data) {
  final tapsRaw = data.taps.map((t) => '${t.$1},${t.$2}').join(';');
  final raw = '${data.seed}|${data.score}|$tapsRaw|${data.senderName}';
  return '$duelCodePrefix${base64Url.encode(utf8.encode(raw))}';
}

/// Giải mã ngược [encodeDuelCode]. `null` nếu thiếu prefix, sai định dạng, số
/// âm, hoặc vượt [kMaxCodeLength]/[kMaxReplayTaps] ([[X25]]).
DuelData? decodeDuelCode(String code) {
  if (code.length > kMaxCodeLength) return null;
  final trimmed = code.trim();
  if (!trimmed.startsWith(duelCodePrefix)) return null;
  try {
    final raw = utf8.decode(
      base64Url.decode(trimmed.substring(duelCodePrefix.length)),
    );
    final b1 = raw.indexOf('|');
    if (b1 < 0) return null;
    final b2 = raw.indexOf('|', b1 + 1);
    if (b2 < 0) return null;
    final b3 = raw.indexOf('|', b2 + 1);
    if (b3 < 0) return null;

    final seed = int.tryParse(raw.substring(0, b1));
    final score = int.tryParse(raw.substring(b1 + 1, b2));
    if (seed == null || score == null || seed < 0 || score < 0) return null;

    final tapsRaw = raw.substring(b2 + 1, b3);
    final taps = <(int, int)>[];
    if (tapsRaw.isNotEmpty) {
      final entries = tapsRaw.split(';');
      if (entries.length > kMaxReplayTaps) return null;
      for (final e in entries) {
        final rc = e.split(',');
        if (rc.length != 2) return null;
        final r = int.tryParse(rc[0]);
        final c = int.tryParse(rc[1]);
        if (r == null || c == null || r < 0 || c < 0) return null;
        taps.add((r, c));
      }
    }
    return DuelData(
      seed: seed,
      taps: taps,
      score: score,
      senderName: raw.substring(b3 + 1),
    );
  } catch (_) {
    return null;
  }
}
