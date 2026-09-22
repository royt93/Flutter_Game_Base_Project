import 'dart:convert';

import 'package:get/get.dart';

import 'reward_transaction_pipeline.dart';
import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

const _maxSupportedCumulativeXp = 0x7fffffff;

/// One rung of the XP curve. [level] is 1-based; the LAST entry in a curve
/// must have [xpToNext] `== 0` — that's what marks it the max level (nothing
/// further to grind toward). Every other entry needs `xpToNext > 0`, and the
/// curve must be non-decreasing (a later level never costs less XP to clear
/// than an earlier one) — see [validateLevelCurve].
class LevelDefinition {
  const LevelDefinition({
    required this.level,
    required this.xpToNext,
    this.unlockRewardLines = const [],
  });

  final int level;
  final int xpToNext;

  /// Granted once, through [RewardTransactionPipeline], the first time a
  /// player reaches [level] — see [PlayerProgressionService.grantXp].
  final List<RewardLine> unlockRewardLines;
}

/// Checks a level curve's structural invariants before it's ever used to
/// grant XP — a broken curve is rejected loudly at construction time
/// ([PlayerProgressionService]'s constructor throws) rather than producing
/// silently-wrong level math later.
SdkFailure<void>? validateLevelCurve(List<LevelDefinition> levels) {
  if (levels.isEmpty) {
    return const SdkFailure(
      kind: SdkErrorKind.validation,
      message: 'Level curve must not be empty',
    );
  }
  final sorted = [...levels]..sort((a, b) => a.level.compareTo(b.level));
  for (var i = 0; i < sorted.length; i++) {
    final expected = i + 1;
    if (sorted[i].level != expected) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'Level curve must be contiguous starting at 1 — expected level '
            '$expected, found ${sorted[i].level} (duplicate or missing level)',
      );
    }
  }

  var cumulative = 0;
  for (var i = 0; i < sorted.length; i++) {
    final def = sorted[i];
    final isLast = i == sorted.length - 1;
    if (isLast) {
      if (def.xpToNext != 0) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message:
              'Last level in the curve must have xpToNext = 0 (marks max level)',
        );
      }
      continue;
    }
    if (def.xpToNext <= 0) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Level ${def.level} must have xpToNext > 0',
      );
    }
    if (i > 0 && def.xpToNext < sorted[i - 1].xpToNext) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'Level curve must be non-decreasing (level ${def.level} costs less than the previous level)',
      );
    }
    cumulative += def.xpToNext;
    if (cumulative < 0 || cumulative > _maxSupportedCumulativeXp) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Level curve cumulative XP overflows the supported range',
      );
    }
  }
  return null;
}

/// Level reached at [totalXp] against [curve] (already validated, sorted by
/// level ascending). Caps at the curve's last (max) level regardless of how
/// far [totalXp] exceeds it.
int levelForTotalXp(List<LevelDefinition> curve, int totalXp) {
  var level = 1;
  var remaining = totalXp;
  for (final def in curve) {
    if (def.xpToNext == 0) break;
    if (remaining < def.xpToNext) break;
    remaining -= def.xpToNext;
    level++;
  }
  return level;
}

/// XP progress within the current level at [totalXp] — always `0` once the
/// max level is reached.
int xpIntoLevelForTotalXp(List<LevelDefinition> curve, int totalXp) {
  var remaining = totalXp;
  for (final def in curve) {
    if (def.xpToNext == 0) return 0;
    if (remaining < def.xpToNext) return remaining;
    remaining -= def.xpToNext;
  }
  return 0;
}

/// Reactive snapshot of one player's progression — [level]/[xpIntoLevel]/
/// [xpToNextLevel] are always derived fresh from [totalXpEarned] against the
/// curve (never persisted directly), so they can never drift out of sync
/// with it.
class PlayerProgressionSnapshot {
  const PlayerProgressionSnapshot({
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
    required this.totalXpEarned,
  });

  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;
  final int totalXpEarned;

  bool get isMaxLevel => xpToNextLevel == 0;
}

/// Fired once per level actually crossed by a [PlayerProgressionService.grantXp]
/// call — a single call that jumps several levels at once fires one of these
/// per level, in ascending order.
class LevelUpEvent {
  const LevelUpEvent({required this.level, required this.rewardLines});
  final int level;
  final List<RewardLine> rewardLines;
}

/// Single source of truth for one player's XP/level — persists
/// [PlayerProgressionSnapshot.totalXpEarned] (never level/xpIntoLevel
/// directly, both are always re-derived from it and the curve) plus a
/// bounded idempotency ledger, same pattern as `EconomyWallet`/
/// `RewardTransactionPipeline` (FEAT-31/FEAT-42): a corrupt save resets to
/// a fresh, never-exploitable state instead of throwing or trusting a
/// partially-decoded value.
class PlayerProgressionService extends GetxService {
  PlayerProgressionService({
    required this.storage,
    required List<LevelDefinition> levelCurve,
    this.pipeline,
    AsyncActionGuard? guard,
    String? storageKey,
    this.capacity = 200,
  }) : _curve = List.unmodifiable(
         [...levelCurve]..sort((a, b) => a.level.compareTo(b.level)),
       ),
       _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? 'player_progression_v1' {
    final error = validateLevelCurve(_curve);
    if (error != null) {
      throw ArgumentError(error.message);
    }
    // BUG-40: see EconomyWallet's constructor for why this can't wait for
    // onInit() alone.
    _hydrate();
    _recompute();
  }

  final StorageService storage;
  final RewardTransactionPipeline? pipeline;
  final int capacity;
  final List<LevelDefinition> _curve;
  final AsyncActionGuard _guard;
  final String _key;

  int _totalXpEarned = 0;
  int _highestUnlockedLevel = 1;
  final _transactions = <String>[];

  final snapshot = const PlayerProgressionSnapshot(
    level: 1,
    xpIntoLevel: 0,
    xpToNextLevel: 0,
    totalXpEarned: 0,
  ).obs;

  /// Fires once per level crossed by the most recent [grantXp] call — `null`
  /// until the first level-up. Not persisted (a UI popup trigger, not
  /// durable state); [PlayerProgressionSnapshot] is the durable source.
  final onLevelUp = Rx<LevelUpEvent?>(null);

  static PlayerProgressionService? get maybe =>
      Get.isRegistered<PlayerProgressionService>()
      ? Get.find<PlayerProgressionService>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _hydrate();
    _recompute();
  }

  void _hydrate() {
    final raw = storage.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _totalXpEarned = asIntOr(
        decoded['totalXpEarned'],
        0,
      ).clamp(0, _maxSupportedCumulativeXp);
      _highestUnlockedLevel = asIntOr(
        decoded['highestUnlockedLevel'],
        1,
      ).clamp(1, _curve.length);
      final rawTransactions = decoded['transactions'];
      if (rawTransactions is List) {
        _transactions
          ..clear()
          ..addAll(rawTransactions.whereType<String>());
      }
    } catch (_) {
      _totalXpEarned = 0;
      _highestUnlockedLevel = 1;
      _transactions.clear();
    }
  }

  Future<void> _persist() => storage.setString(
    _key,
    jsonEncode({
      'totalXpEarned': _totalXpEarned,
      'highestUnlockedLevel': _highestUnlockedLevel,
      'transactions': _transactions,
    }),
  );

  void _recompute() {
    final level = levelForTotalXp(_curve, _totalXpEarned);
    final xpIntoLevel = xpIntoLevelForTotalXp(_curve, _totalXpEarned);
    final xpToNext = _curve[level - 1].xpToNext;
    snapshot.value = PlayerProgressionSnapshot(
      level: level,
      xpIntoLevel: xpIntoLevel,
      xpToNextLevel: xpToNext,
      totalXpEarned: _totalXpEarned,
    );
  }

  /// Grants [amount] XP under [transactionId] (idempotent — calling this
  /// again with the same id, even after a restart, is a no-op that returns
  /// the current snapshot). If this crosses one or more level thresholds,
  /// each newly-reached level's [LevelDefinition.unlockRewardLines] (if any)
  /// is granted exactly once through [pipeline] (when supplied), and
  /// [onLevelUp] fires once per level, in order — the level is capped at the
  /// curve's max level regardless of how much XP is granted past it.
  Future<SdkResult<PlayerProgressionSnapshot>> grantXp({
    required int amount,
    required String transactionId,
  }) => _guard.runExclusive('progression', () async {
    if (amount <= 0 || transactionId.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid XP grant',
      );
    }
    if (_transactions.contains(transactionId)) {
      return SdkSuccess(snapshot.value);
    }

    final nextTotal = _totalXpEarned + amount;
    if (nextTotal < _totalXpEarned || nextTotal > _maxSupportedCumulativeXp) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'XP grant would overflow the supported range',
      );
    }

    final newLevel = levelForTotalXp(_curve, nextTotal);
    final leveledUpTo = [
      for (var lvl = _highestUnlockedLevel + 1; lvl <= newLevel; lvl++) lvl,
    ];

    _totalXpEarned = nextTotal;
    _appendTransaction(transactionId);
    if (leveledUpTo.isNotEmpty) _highestUnlockedLevel = newLevel;
    await _persist();
    _recompute();

    for (final lvl in leveledUpTo) {
      final def = _curve[lvl - 1];
      if (def.unlockRewardLines.isNotEmpty && pipeline != null) {
        await pipeline!.grant(
          source: RewardSource.other,
          transactionId: 'level_up:$lvl',
          lines: def.unlockRewardLines,
        );
      }
      onLevelUp.value = LevelUpEvent(
        level: lvl,
        rewardLines: def.unlockRewardLines,
      );
    }

    return SdkSuccess(snapshot.value);
  });

  void _appendTransaction(String transactionId) {
    _transactions.add(transactionId);
    if (_transactions.length > capacity) {
      _transactions.removeRange(0, _transactions.length - capacity);
    }
  }
}
