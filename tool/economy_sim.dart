// Headless economy/balancing simulator (IDEA-36) — no Flutter runtime
// dependency, no game runtime dependency. Fast-forwards a scripted
// session pattern (N sessions/day, spent energy per session) through
// `EnergyService`'s regen math and `OfflineProgressionService`'s
// earnings math, and prints the resulting energy/currency curve across
// simulated days.
//
// Calls the SAME pure functions those services delegate to
// (`lib/core/utils/economy_math.dart`) rather than reimplementing the
// formulas — so this simulator can never silently drift out of sync with
// what the real game actually does. See `test/tool/economy_sim_test.dart`
// for the cross-check that proves this against the real services.
//
// Usage:
//   dart run tool/economy_sim.dart [--days=30] [--sessionsPerDay=3]
//     [--energyPerSession=2] [--maxEnergy=5] [--refillMinutes=30]
//     [--sessionSpacingHours=4] [--offlineCapHours=8]
//     [--productionRatePerSecond=0.01]
import 'dart:io';

import 'package:roy_casual_kit/core/utils/economy_math.dart';

/// One scenario day's end-of-day snapshot.
class EconomyDaySnapshot {
  const EconomyDaySnapshot({
    required this.day,
    required this.endEnergyCount,
    required this.cumulativeCurrency,
  });

  final int day;
  final int endEnergyCount;
  final double cumulativeCurrency;
}

/// A scripted "N sessions/day, M energy spent per session" playtest
/// scenario — every duration is expressed in whole milliseconds so the
/// simulation stays exact integer arithmetic, matching what
/// `nowMsClamped()`-driven real services actually operate on.
class EconomyScenario {
  const EconomyScenario({
    required this.days,
    required this.sessionsPerDay,
    required this.energyPerSession,
    required this.maxEnergy,
    required this.refillIntervalMs,
    required this.sessionSpacingMs,
    required this.maxOfflineCapMs,
    required this.productionRatePerSecond,
  });

  final int days;
  final int sessionsPerDay;
  final int energyPerSession;
  final int maxEnergy;
  final int refillIntervalMs;
  final int sessionSpacingMs;
  final int maxOfflineCapMs;
  final double productionRatePerSecond;
}

/// Runs [scenario] and returns 1 [EconomyDaySnapshot] per simulated day.
///
/// Each session: claims offline earnings accrued since the last session
/// (via [offlineEarnings]), regenerates energy up to the current
/// simulated instant (via [regenEnergy]), then spends
/// [EconomyScenario.energyPerSession] — mirroring
/// `EnergyService.consumeEnergy`'s own rule of deducting nothing (and
/// resetting the regen baseline only when spending from a full bar) when
/// there isn't enough energy, rather than inventing a different rule here.
List<EconomyDaySnapshot> simulateEconomy(EconomyScenario scenario) {
  var energyCount = scenario.maxEnergy;
  var energyLastMs = 0;
  var lastClaimedMs = 0;
  var currency = 0.0;
  var nowMs = 0;
  final snapshots = <EconomyDaySnapshot>[];

  for (var day = 1; day <= scenario.days; day++) {
    for (var session = 0; session < scenario.sessionsPerDay; session++) {
      currency += offlineEarnings(
        lastClaimedMs: lastClaimedMs,
        nowMs: nowMs,
        maxOfflineCapMs: scenario.maxOfflineCapMs,
        productionRatePerSecond: scenario.productionRatePerSecond,
      );
      lastClaimedMs = nowMs;

      final regenResult = regenEnergy(
        count: energyCount,
        maxEnergy: scenario.maxEnergy,
        lastMs: energyLastMs,
        nowMs: nowMs,
        intervalMs: scenario.refillIntervalMs,
      );
      energyCount = regenResult.count;
      energyLastMs = regenResult.lastMs;

      if (energyCount >= scenario.energyPerSession) {
        final wasFull = energyCount >= scenario.maxEnergy;
        energyCount -= scenario.energyPerSession;
        if (wasFull) energyLastMs = nowMs;
      }

      nowMs += scenario.sessionSpacingMs;
    }

    snapshots.add(
      EconomyDaySnapshot(
        day: day,
        endEnergyCount: energyCount,
        cumulativeCurrency: currency,
      ),
    );
  }

  return snapshots;
}

const _defaults = <String, Object>{
  'days': 30,
  'sessionsPerDay': 3,
  'energyPerSession': 2,
  'maxEnergy': 5,
  'refillMinutes': 30,
  'sessionSpacingHours': 4,
  'offlineCapHours': 8,
  'productionRatePerSecond': 0.01,
};

/// Parses `--key=value` CLI args over [_defaults]; unrecognized keys and
/// malformed values are ignored (the corresponding default is kept) —
/// this is a local balancing tool, not a user-facing CLI that needs to
/// reject bad input loudly.
Map<String, Object> parseArgs(List<String> args) {
  final options = Map<String, Object>.of(_defaults);
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('=')) continue;
    final eqIndex = arg.indexOf('=');
    final key = arg.substring(2, eqIndex);
    final rawValue = arg.substring(eqIndex + 1);
    final current = options[key];
    if (current is int) {
      final parsed = int.tryParse(rawValue);
      if (parsed != null) options[key] = parsed;
    } else if (current is double) {
      final parsed = double.tryParse(rawValue);
      if (parsed != null) options[key] = parsed;
    }
  }
  return options;
}

EconomyScenario scenarioFrom(Map<String, Object> options) => EconomyScenario(
  days: options['days']! as int,
  sessionsPerDay: options['sessionsPerDay']! as int,
  energyPerSession: options['energyPerSession']! as int,
  maxEnergy: options['maxEnergy']! as int,
  refillIntervalMs: (options['refillMinutes']! as int) * 60000,
  sessionSpacingMs: (options['sessionSpacingHours']! as int) * 3600000,
  maxOfflineCapMs: (options['offlineCapHours']! as int) * 3600000,
  productionRatePerSecond: options['productionRatePerSecond']! as double,
);

void main(List<String> args) {
  final scenario = scenarioFrom(parseArgs(args));
  final snapshots = simulateEconomy(scenario);

  final header = '${'day'.padRight(6)}${'endEnergy'.padRight(12)}cumulativeCurrency';
  stdout.writeln(header);
  for (final snapshot in snapshots) {
    final dayCol = '${snapshot.day}'.padRight(6);
    final energyCol = '${snapshot.endEnergyCount}'.padRight(12);
    final currencyCol = snapshot.cumulativeCurrency.toStringAsFixed(2);
    stdout.writeln('$dayCol$energyCol$currencyCol');
  }
}
