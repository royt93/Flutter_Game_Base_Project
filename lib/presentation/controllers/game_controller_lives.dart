part of 'game_controller.dart';

/// Lives / energy: mạng hồi theo thời gian + mua đầy bằng xu.
extension GameControllerLives on GameController {
  static const int _regenMs = GameController.regenSeconds * 1000;

  bool get hasLife => lives.value > 0;

  /// Hồi mạng theo thời gian đã trôi qua kể từ mốc [livesRegenAt].
  void refillLives() {
    if (lives.value >= GameController.maxLives) return;
    final now = clock().millisecondsSinceEpoch;
    var regenAt = _store.getInt(StorageKeys.livesRegenAt, def: 0);
    if (regenAt == 0) {
      // trạng thái thiếu mốc (vd lần đầu cài < max) → đặt mốc hồi từ giờ
      regenAt = now + _regenMs;
      unawaited(_store.setInt(StorageKeys.livesRegenAt, regenAt));
      return;
    }
    if (now < regenAt) return;
    final elapsed = now - regenAt;
    final gained = 1 + elapsed ~/ _regenMs;
    lives.value = (lives.value + gained).clamp(0, GameController.maxLives);
    if (lives.value >= GameController.maxLives) {
      unawaited(_store.remove(StorageKeys.livesRegenAt));
    } else {
      final remainder = elapsed % _regenMs;
      unawaited(
        _store.setInt(StorageKeys.livesRegenAt, now - remainder + _regenMs),
      );
    }
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
  }

  /// Mua đầy mạng bằng xu. Trả về false nếu đã đầy hoặc thiếu xu.
  bool buyRefillLives({int price = 60}) {
    if (lives.value >= GameController.maxLives) return false;
    if (coins.value < price) return false;
    lives.value = GameController.maxLives;
    unawaited(_store.remove(StorageKeys.livesRegenAt));
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
    _setCoins(coins.value - price);
    return true;
  }

  /// Trừ 1 mạng (khi thua). Trả về false nếu đã hết mạng.
  bool consumeLife() {
    if (lives.value <= 0) return false;
    final wasMax = lives.value >= GameController.maxLives;
    lives.value--;
    if (wasMax) {
      // vừa rời mức tối đa → bắt đầu đếm hồi
      unawaited(
        _store.setInt(
          StorageKeys.livesRegenAt,
          clock().millisecondsSinceEpoch + _regenMs,
        ),
      );
    }
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
    return true;
  }

  /// Thời gian còn lại tới khi hồi 1 mạng (Duration.zero nếu đầy/không chờ).
  Duration get timeToNextLife {
    if (lives.value >= GameController.maxLives) return Duration.zero;
    final regenAt = _store.getInt(StorageKeys.livesRegenAt, def: 0);
    if (regenAt == 0) return Duration.zero;
    final ms = regenAt - clock().millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }
}
