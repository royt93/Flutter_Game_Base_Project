part of 'game_controller.dart';

/// W18.3 — coin-sink: giá nâng cấp booster vĩnh viễn (đắt để hút xu dư) + hiệu lực.
const int kUpgradeHammerPrice = 400; // búa 1 ô → 3×3
const int kUpgradeMovesPrice = 350; // +Lượt 10 → 15
const int kMovesUpgradedBonus = 15;

/// Booster: dùng (use*), mua bằng xu (buy*) và tặng (grant*).
extension GameControllerBooster on GameController {
  // --- Dùng booster ---
  bool useHammer() => _useBooster(StorageKeys.bHammer, boosterHammer);

  /// +10 lượt (W18.3: +15 nếu đã nâng cấp). Trả về true nếu còn booster.
  bool useMovesBooster() {
    if (!_useBooster(StorageKeys.bMoves, boosterMoves)) return false;
    movesLeft.value += movesUpgraded.value ? kMovesUpgradedBonus : 10;
    return true;
  }

  bool useSwap() => _useBooster(StorageKeys.bSwap, boosterSwap);
  bool useBomb() => _useBooster(StorageKeys.bBomb, boosterBomb);
  bool useColor() => _useBooster(StorageKeys.bColor, boosterColor);
  bool useJoker() => _useBooster(StorageKeys.bJoker, boosterJoker);
  bool useLightning() => _useBooster(StorageKeys.bLightning, boosterLightning);
  bool useRoyal() => _useBooster(StorageKeys.bRoyal, boosterRoyal);
  bool useGravity() => _useBooster(StorageKeys.bGravity, boosterGravity);

  bool _useBooster(String key, RxInt count) {
    if (count.value <= 0) return false;
    count.value--;
    unawaited(_store.setInt(key, count.value));
    return true;
  }

  // --- Mua booster bằng xu ---
  bool buyHammer({int price = 30}) =>
      _buy(StorageKeys.bHammer, boosterHammer, price);
  bool buyMoves({int price = 40}) =>
      _buy(StorageKeys.bMoves, boosterMoves, price);
  bool buySwap({int price = 40}) => _buy(StorageKeys.bSwap, boosterSwap, price);
  bool buyBomb({int price = 50}) => _buy(StorageKeys.bBomb, boosterBomb, price);
  bool buyColor({int price = 80}) =>
      _buy(StorageKeys.bColor, boosterColor, price);
  bool buyJoker({int price = 60}) =>
      _buy(StorageKeys.bJoker, boosterJoker, price);
  bool buyLightning({int price = 60}) =>
      _buy(StorageKeys.bLightning, boosterLightning, price);
  bool buyRoyal({int price = 120}) =>
      _buy(StorageKeys.bRoyal, boosterRoyal, price);
  bool buyGravity({int price = 50}) =>
      _buy(StorageKeys.bGravity, boosterGravity, price);

  bool _buy(String key, RxInt count, int price) {
    if (coins.value < price) return false;
    // Cộng booster TRƯỚC rồi mới trừ xu: nếu app bị kill giữa 2 lượt ghi đĩa,
    // người chơi mất ít rủi ro hơn (giữ booster) thay vì mất xu trắng.
    count.value++;
    unawaited(_store.setInt(key, count.value));
    _setCoins(coins.value - price);
    return true;
  }

  // --- Tặng booster (vòng quay / pre-game / Battle Pass) ---
  void _grant(String key, RxInt count, int n) {
    count.value += n;
    unawaited(_store.setInt(key, count.value));
  }

  void grantHammer([int n = 1]) =>
      _grant(StorageKeys.bHammer, boosterHammer, n);
  void grantMovesBooster([int n = 1]) =>
      _grant(StorageKeys.bMoves, boosterMoves, n);
  void grantBomb([int n = 1]) => _grant(StorageKeys.bBomb, boosterBomb, n);
  void grantSwap([int n = 1]) => _grant(StorageKeys.bSwap, boosterSwap, n);
  // Booster độc quyền — nguồn nhận qua Battle Pass (xem kPassTiers).
  void grantColor([int n = 1]) => _grant(StorageKeys.bColor, boosterColor, n);
  void grantJoker([int n = 1]) => _grant(StorageKeys.bJoker, boosterJoker, n);
  void grantLightning([int n = 1]) =>
      _grant(StorageKeys.bLightning, boosterLightning, n);
  void grantRoyal([int n = 1]) => _grant(StorageKeys.bRoyal, boosterRoyal, n);
  void grantGravity([int n = 1]) =>
      _grant(StorageKeys.bGravity, boosterGravity, n);

  // --- W18.3: Nâng cấp booster VĨNH VIỄN (coin-sink) ---
  /// Mua nâng cấp Búa (1 ô → 3×3). Trả false nếu đã nâng cấp / thiếu xu.
  /// Ghi cờ TRƯỚC khi trừ xu (an toàn nếu kill giữa chừng → giữ nâng cấp).
  bool buyUpgradeHammer() {
    if (hammerUpgraded.value || coins.value < kUpgradeHammerPrice) return false;
    hammerUpgraded.value = true;
    unawaited(_store.setInt(StorageKeys.upgHammer, 1));
    _setCoins(coins.value - kUpgradeHammerPrice);
    return true;
  }

  /// Mua nâng cấp +Lượt (10 → 15). Trả false nếu đã nâng cấp / thiếu xu.
  bool buyUpgradeMoves() {
    if (movesUpgraded.value || coins.value < kUpgradeMovesPrice) return false;
    movesUpgraded.value = true;
    unawaited(_store.setInt(StorageKeys.upgMoves, 1));
    _setCoins(coins.value - kUpgradeMovesPrice);
    return true;
  }

  /// Trao phần thưởng theo [kind] + [amount] — gom 1 chỗ (trước đây switch 8-case
  /// lặp ở Season/Tournament/BattlePass claim). W18.1.
  void grantReward(RewardKind kind, int amount) {
    switch (kind) {
      case RewardKind.coins:
        addCoins(amount);
      case RewardKind.hammer:
        grantHammer(amount);
      case RewardKind.moves:
        grantMovesBooster(amount);
      case RewardKind.color:
        grantColor(amount);
      case RewardKind.joker:
        grantJoker(amount);
      case RewardKind.lightning:
        grantLightning(amount);
      case RewardKind.royal:
        grantRoyal(amount);
      case RewardKind.gravity:
        grantGravity(amount);
    }
  }
}
