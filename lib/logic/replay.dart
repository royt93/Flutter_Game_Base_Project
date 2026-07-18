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

/// Giải mã ngược [encodeReplay]. Trả `null` nếu mã sai định dạng, thiếu cột,
/// số âm, hoặc 1 tap không đúng định dạng `row,col` — không throw để callsite
/// chỉ cần check null (không phân biệt lỗi cụ thể, mã giả mạo/hỏng đều `null`).
ReplayData? decodeReplay(String code) {
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
      for (final entry in tapsRaw.split(';')) {
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
