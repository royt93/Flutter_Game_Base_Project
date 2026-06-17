part of 'game_controller.dart';

/// Kinh tế xu (gán/cộng/tiêu + migrate shard cũ) + thưởng đăng nhập hằng ngày
/// + ngày epoch hiệu lực (chống chỉnh giờ LÙI).
extension GameControllerEconomy on GameController {
  /// Gán xu (đã clamp [0, maxCoins]) + persist. Mọi thay đổi xu đi qua đây để
  /// tránh overflow & gom 1 chỗ ghi đĩa.
  void _setCoins(int value) {
    coins.value = value.clamp(0, GameController.maxCoins);
    unawaited(_store.setInt(StorageKeys.coins, coins.value));
  }

  /// Cộng xu (thưởng thành tựu / vòng quay…) + persist.
  void addCoins(int amount) {
    if (isVersus.value || amount <= 0) return; // versus không đụng kinh tế
    _setCoins(coins.value + amount);
  }

  /// Tiêu xu (xây Đền Neon, mua skin/theme cửa hàng…). Trả về false nếu không đủ.
  bool spendCoins(int amount) {
    if (amount <= 0 || coins.value < amount) return false;
    _setCoins(coins.value - amount);
    return true;
  }

  /// Wave 9 — GỘP tiền tệ: quy đổi shard cũ → xu (1 shard = 10 xu), CHẠY 1 LẦN.
  /// Không xoá tiến trình người chơi: số shard đang giữ cộng thẳng vào xu.
  void _migrateShardsToCoins() {
    if (_store.getInt(StorageKeys.shardsMigrated, def: 0) == 1) return;
    final old = _store.getInt(StorageKeys.shards, def: 0);
    if (old > 0) {
      _setCoins(coins.value + old * 10);
      unawaited(_store.setInt(StorageKeys.shards, 0));
    }
    unawaited(_store.setInt(StorageKeys.shardsMigrated, 1));
  }

  // --------------------------------------------------------------------------
  // Ngày epoch — chống chỉnh giờ lùi
  // --------------------------------------------------------------------------
  int get _todayEpochDay {
    final n = clock();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;
  }

  /// Epoch-day "hiệu lực" — chống chỉnh giờ LÙI: không nhỏ hơn ngày cao nhất
  /// từng thấy. Chỉnh giờ lùi → giữ ngày cũ (không cho nhận lại quà). (Chỉnh giờ
  /// TIẾN không chặn được offline — chấp nhận, chỉ tự hại người chơi.)
  int get _effectiveDay {
    final today = _todayEpochDay;
    // def: 0 (KHÔNG phải `today`) — nếu để def=today thì `today > maxSeen` luôn
    // false ⇒ maxDay KHÔNG bao giờ được ghi ⇒ bảo vệ lùi-giờ thành code chết.
    // Với def=0: lần đầu ghi maxDay=today; về sau giữ ngày CAO NHẤT từng thấy.
    final maxSeen = _store.getInt(StorageKeys.maxDay, def: 0);
    if (today >= maxSeen) {
      if (today > maxSeen) unawaited(_store.setInt(StorageKeys.maxDay, today));
      return today;
    }
    return maxSeen;
  }

  /// Ngày epoch công khai (đã chống chỉnh giờ lùi) — daily/wheel/quest/season dùng.
  int get todayEpochDay => _effectiveDay;

  // --------------------------------------------------------------------------
  // Daily reward (thưởng đăng nhập hằng ngày)
  // --------------------------------------------------------------------------
  /// Chưa nhận quà hôm nay? (dùng ngày hiệu lực — chống chỉnh giờ lùi)
  bool get canClaimDaily =>
      _store.getInt(StorageKeys.dailyLastClaim, def: -1) != _effectiveDay;

  /// Xu thưởng cho ngày thứ [day] trong chuỗi (1-based), chu kỳ 7 ngày:
  /// 20, 35, 50, 65, 80, 95, 110 rồi lặp lại.
  int dailyRewardFor(int day) {
    final d = ((day - 1) % 7) + 1; // 1..7
    return 20 + (d - 1) * 15;
  }

  /// Nhận quà hằng ngày. Trả về số xu nhận (0 nếu đã nhận hôm nay).
  int claimDaily() {
    if (!canClaimDaily) return 0;
    final today = _effectiveDay;
    final last = _store.getInt(StorageKeys.dailyLastClaim, def: -1);
    // liên tục (hôm qua) → +1; gãy hoặc lần đầu → reset về 1
    dailyStreak.value = (last == today - 1) ? dailyStreak.value + 1 : 1;
    final reward = dailyRewardFor(dailyStreak.value);
    // Ghi mốc "đã nhận hôm nay" TRƯỚC khi cộng xu: nếu kill giữa chừng, tránh
    // exploit nhận thưởng nhiều lần (xấu nhất là mất 1 lượt thưởng, không lặp).
    unawaited(_store.setInt(StorageKeys.dailyLastClaim, today));
    unawaited(_store.setInt(StorageKeys.dailyStreak, dailyStreak.value));
    _setCoins(coins.value + reward);
    return reward;
  }
}
