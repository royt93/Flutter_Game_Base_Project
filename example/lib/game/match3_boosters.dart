import 'package:roy_casual_kit/roy_casual_kit.dart';

/// Shared inventory catalog for the example app. `InventoryService` is a Get
/// singleton keyed by type, so every screen that registers it must use this
/// same catalog or a booster id would be unknown after another screen won
/// the registration race.
const exampleInventoryCatalog = <String, ItemDefinition>{
  'potion': ItemDefinition(id: 'potion', maxStack: 99),
  'sword': ItemDefinition(
    id: 'sword',
    equippable: true,
    rarity: ItemRarity.rare,
  ),
  'skin_dragon': ItemDefinition(id: 'skin_dragon'),
  'booster_row': ItemDefinition(id: 'booster_row', maxStack: 99),
  'booster_column': ItemDefinition(id: 'booster_column', maxStack: 99),
  'booster_bomb': ItemDefinition(id: 'booster_bomb', maxStack: 99),
};

const match3BoosterPrice = 30;
const match3StarterBoosters = 1;

const match3BoosterItemIds = <Match3Booster, String>{
  Match3Booster.rowClear: 'booster_row',
  Match3Booster.columnClear: 'booster_column',
  Match3Booster.bomb: 'booster_bomb',
};

/// Grants one starter booster of each kind exactly once per install.
/// Idempotent via the inventory's own transaction id, so calling it on every
/// screen open is safe.
Future<void> grantStarterBoosters(InventoryService inventory) async {
  await inventory.grant(
    lines: [
      for (final id in match3BoosterItemIds.values)
        InventoryLine(itemId: id, quantity: match3StarterBoosters),
    ],
    transactionId: 'match3_starter_boosters_v1',
  );
}

/// Buys one [booster] for [match3BoosterPrice] coins. The coin spend and the
/// inventory grant are two services, so a failed grant refunds the coins;
/// both legs use ids derived from [purchaseId] so a retry is a no-op.
Future<SdkResult<void>> buyBooster({
  required EconomyWallet wallet,
  required InventoryService inventory,
  required Match3Booster booster,
  required String purchaseId,
}) async {
  final spend = await wallet.trySpend(
    currency: 'coins',
    amount: match3BoosterPrice,
    transactionId: 'match3_buy_$purchaseId',
  );
  if (spend case SdkFailure<int>(:final kind, :final message)) {
    return SdkFailure(kind: kind, message: message);
  }
  final grant = await inventory.grant(
    lines: [InventoryLine(itemId: match3BoosterItemIds[booster]!, quantity: 1)],
    transactionId: 'match3_buy_grant_$purchaseId',
  );
  if (grant case SdkFailure<InventorySnapshot>(:final kind, :final message)) {
    await wallet.earn(
      currency: 'coins',
      amount: match3BoosterPrice,
      transactionId: 'match3_buy_refund_$purchaseId',
    );
    return SdkFailure(kind: kind, message: message);
  }
  return const SdkSuccess<void>(null);
}

/// Spends one [booster] from the inventory. Returns false when none is left
/// or the inventory write fails, so the caller must not apply the effect.
Future<bool> consumeBooster({
  required InventoryService inventory,
  required Match3Booster booster,
  required String useId,
}) async {
  final result = await inventory.consume(
    lines: [InventoryLine(itemId: match3BoosterItemIds[booster]!, quantity: 1)],
    transactionId: 'match3_use_$useId',
  );
  return result is SdkSuccess<InventorySnapshot>;
}

/// 1 to 3 stars for a won level from the moves left: >= 40% of the level's
/// moves is 3 stars, >= 15% is 2, otherwise 1. Thresholds were checked with
/// `tool/match3_sim.dart` (random bots earn 3 stars on roughly 20-35% of wins,
/// the greedy bot on most).
int match3StarsFor({required int movesLeft, required int moveLimit}) {
  if (moveLimit <= 0) {
    throw ArgumentError.value(moveLimit, 'moveLimit', 'must be > 0');
  }
  final ratio = movesLeft.clamp(0, moveLimit) / moveLimit;
  return ratio >= 0.4 ? 3 : (ratio >= 0.15 ? 2 : 1);
}

/// Per-level best stars from a saved `bestStars` map, ignoring anything that
/// is not a level number in range or a star count in 1..3 (a save may come
/// from an older build or a cloud copy).
Map<int, int> match3ReadBestStars(Object? raw, int levelCount) {
  final result = <int, int>{};
  if (raw is! Map) return result;
  for (final entry in raw.entries) {
    final level = int.tryParse('${entry.key}');
    final stars = entry.value;
    if (level != null &&
        level >= 1 &&
        level <= levelCount &&
        stars is int &&
        stars >= 1 &&
        stars <= 3) {
      result[level] = stars;
    }
  }
  return result;
}

/// Merges two best-stars maps keeping the higher count per level.
Map<int, int> match3MergeBestStars(Map<int, int> a, Map<int, int> b) => {
  for (final level in {...a.keys, ...b.keys})
    level: (a[level] ?? 0) > (b[level] ?? 0) ? a[level]! : b[level]!,
};
