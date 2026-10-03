import 'package:get/get.dart';

import 'economy_wallet.dart';
import 'utils/economy_math.dart';
import 'utils/sdk_result.dart';

/// The classic idle/incremental-game "prestige"/"ascension" loop (Cookie
/// Clicker, Adventure Capitalist, ...): once [primaryCurrency] reaches
/// [prestigeThreshold], the player can soft-reset [softResetCurrencies]
/// (wiped back to 0) in exchange for [relicsPerPrestige] of
/// [metaCurrency] — a currency that's NEVER soft-reset, and permanently
/// raises [currentMultiplier] via [prestigeMultiplier] (`economy_math.dart`,
/// the pure formula this and `tool/economy_sim.dart`'s balancing simulator
/// both call, so they can't silently drift apart).
///
/// Built entirely on [EconomyWallet]'s existing `balanceOf`/`earn`/
/// `trySpend` — no separate storage of its own, no new persistence format
/// to keep in sync: relics (and every soft-reset currency) already persist
/// exactly like any other wallet balance.
///
/// [currentMultiplier] is a pure read — applying it to
/// [OfflineProgressionService]/[EnergyService]'s own rate/interval
/// parameters is the CALLER's job (both take a caller-supplied rate rather
/// than deriving one themselves, so there's no coupling to introduce here
/// — see `example/`'s Cookbook demo for the integration).
class PrestigeService extends GetxService {
  PrestigeService({
    required this.wallet,
    this.primaryCurrency = 'coins',
    this.metaCurrency = 'relics',
    this.prestigeThreshold = 1000,
    this.bonusPerRelic = 0.1,
    this.relicsPerPrestige = 1,
    this.softResetCurrencies = const {'coins'},
  }) {
    // ENH-89: was `assert(!softResetCurrencies.contains(metaCurrency),
    // ...)` — stripped entirely in release builds. A misconfigured
    // `softResetCurrencies` that also lists `metaCurrency` would then
    // silently wipe relics on every prestige in production — the exact
    // bug this invariant exists to prevent, undetected until a player
    // notices their relics vanishing. A plain `if`/`throw` is never
    // stripped, in any build mode.
    if (softResetCurrencies.contains(metaCurrency)) {
      throw ArgumentError.value(
        softResetCurrencies,
        'softResetCurrencies',
        'must not contain metaCurrency ("$metaCurrency") — metaCurrency '
            'must survive a prestige',
      );
    }
  }

  final EconomyWallet wallet;

  /// The currency [canPrestige]/[prestige] check against [prestigeThreshold].
  final String primaryCurrency;

  /// The permanent currency [prestige] grants — never soft-reset, and the
  /// only input to [currentMultiplier].
  final String metaCurrency;

  /// Minimum [primaryCurrency] balance required to [prestige].
  final int prestigeThreshold;

  /// Multiplier bonus each unit of [metaCurrency] grants — see
  /// [prestigeMultiplier].
  final double bonusPerRelic;

  /// How much [metaCurrency] one [prestige] call grants.
  final int relicsPerPrestige;

  /// Currencies wiped to 0 by [prestige] — [metaCurrency] can never be one
  /// of these (enforced by the constructor's `assert`).
  final Set<String> softResetCurrencies;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static PrestigeService? get maybe =>
      Get.isRegistered<PrestigeService>() ? Get.find<PrestigeService>() : null;

  int _txCounter = 0;

  /// Whether [primaryCurrency]'s current balance meets [prestigeThreshold].
  bool canPrestige() => wallet.balanceOf(primaryCurrency) >= prestigeThreshold;

  /// The permanent earn-rate multiplier currently in effect, derived from
  /// [metaCurrency]'s current balance — `1` if the player has never
  /// prestiged (0 relics).
  double get currentMultiplier => prestigeMultiplier(
    relics: wallet.balanceOf(metaCurrency),
    bonusPerRelic: bonusPerRelic,
  );

  /// Soft-resets every currency in [softResetCurrencies] to 0, then grants
  /// [relicsPerPrestige] of [metaCurrency] — returns the new [metaCurrency]
  /// balance on success. Fails with [SdkErrorKind.validation] (no state
  /// change at all) if [canPrestige] is false.
  ///
  /// BUG-90: every reset + the relic grant commit as ONE
  /// [EconomyWallet.batchTransaction] — one combined balance update, one
  /// disk write. A balance that can't go negative (already enforced inside
  /// the batch) fails the WHOLE prestige with nothing changed; a storage
  /// error partway used to leave some currencies already reset with no
  /// relic grant (a real, previously-reachable half-applied state) — the
  /// batch either fully applies or fully doesn't.
  Future<SdkResult<int>> prestige() async {
    if (!canPrestige()) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'Not enough $primaryCurrency to prestige (need '
            '$prestigeThreshold, have ${wallet.balanceOf(primaryCurrency)})',
      );
    }

    final deltas = <String, int>{};
    for (final currency in softResetCurrencies) {
      final balance = wallet.balanceOf(currency);
      if (balance <= 0) continue;
      deltas[currency] = -balance;
    }
    deltas[metaCurrency] = (deltas[metaCurrency] ?? 0) + relicsPerPrestige;

    final result = await wallet.batchTransaction(
      deltas: deltas,
      transactionId: 'prestige_${_txCounter++}',
    );
    if (result is SdkFailure<void>) {
      return SdkFailure(
        kind: result.kind,
        message: result.message,
        retryable: result.retryable,
        cause: result.cause,
        stackTrace: result.stackTrace,
      );
    }
    return SdkSuccess(wallet.balanceOf(metaCurrency));
  }
}
