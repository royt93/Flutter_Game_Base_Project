/// Pure-Dart performance budget / regression-check framework (FEAT-80).
///
/// Consumes already-measured [PerformanceBudgetMetric]s — produced by
/// `tool/performance_budget_check.dart` from a real headless benchmark
/// and/or a real-device smoke-test run, never fabricated here — and checks
/// them against a [BudgetPolicy] list, optionally comparing against a
/// committed [PerformanceBudgetMetric] baseline for regression detection.
/// No I/O, no Flutter dependency.
///
/// Honesty rules baked into [checkPerformanceBudgets]:
/// - A metric a policy names but no measurement was supplied for is a
///   [PerformanceBudgetViolationKind.missingMeasurement] failure, never a
///   silent skip — an unmeasured budget is not a passed budget.
/// - A policy that requires [MeasurementSource.realDevice] fails outright
///   ([PerformanceBudgetViolationKind.wrongSource]) if only a
///   [MeasurementSource.hostHeadless] value was supplied for that metric —
///   a host number never silently counts as device proof.
library;

import 'safe_json.dart';

/// Where a [PerformanceBudgetMetric]'s value actually came from.
enum MeasurementSource { hostHeadless, realDevice }

/// Whether a budget's [BudgetPolicy.limit] is a ceiling or a floor.
enum BudgetDirection { atMost, atLeast }

enum PerformanceBudgetViolationKind {
  missingMeasurement,
  wrongSource,
  staleMeasurement,
  budgetExceeded,
  regression,
}

/// One measured value — e.g. an allocation-reduction percentage from
/// `tool/object_pool_benchmark.dart`, or a real-device app-boot wall time.
class PerformanceBudgetMetric {
  const PerformanceBudgetMetric({
    required this.name,
    required this.source,
    required this.value,
    required this.unit,
    this.recordedAtMs,
  });

  final String name;
  final MeasurementSource source;
  final double value;
  final String unit;

  /// When this value was actually measured. Required for
  /// [BudgetPolicy.maxAgeMs] staleness checks (mainly meaningful for a
  /// [MeasurementSource.realDevice] metric carried forward in a committed
  /// baseline between real smoke-test runs); `null` for a metric always
  /// re-measured fresh in the same process (e.g. a headless benchmark).
  final int? recordedAtMs;

  Map<String, Object?> toJson() => {
    'name': name,
    'source': source.name,
    'value': value,
    'unit': unit,
    if (recordedAtMs != null) 'recordedAtMs': recordedAtMs,
  };

  factory PerformanceBudgetMetric.fromJson(Map<String, Object?> json) =>
      PerformanceBudgetMetric(
        name: asStringOr(json['name'], ''),
        source: MeasurementSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => MeasurementSource.hostHeadless,
        ),
        value: asDoubleOr(json['value'], 0),
        unit: asStringOr(json['unit'], ''),
        recordedAtMs: json['recordedAtMs'] == null
            ? null
            : asIntOr(json['recordedAtMs'], 0),
      );
}

/// One budget rule a named metric must satisfy.
class BudgetPolicy {
  const BudgetPolicy({
    required this.metricName,
    required this.requiredSource,
    required this.direction,
    required this.limit,
    this.regressionTolerancePercent,
    this.maxAgeMs,
  });

  final String metricName;
  final MeasurementSource requiredSource;
  final BudgetDirection direction;
  final double limit;

  /// If set (and a baseline metric with the same name is supplied), a
  /// fresh value worse than the baseline by more than this percentage is
  /// flagged as [PerformanceBudgetViolationKind.regression] — separate
  /// from an absolute [PerformanceBudgetViolationKind.budgetExceeded],
  /// since a value can regress while still sitting under the hard limit.
  final double? regressionTolerancePercent;

  /// If set, a measurement older than this (relative to `nowMs` passed to
  /// [checkPerformanceBudgets]) is [PerformanceBudgetViolationKind.staleMeasurement]
  /// rather than silently trusted forever — forces a periodic re-run of
  /// whatever produced it (mainly a real-device smoke test).
  final int? maxAgeMs;

  factory BudgetPolicy.fromJson(Map<String, Object?> json) => BudgetPolicy(
    metricName: asStringOr(json['metricName'], ''),
    requiredSource: MeasurementSource.values.firstWhere(
      (s) => s.name == json['requiredSource'],
      orElse: () => MeasurementSource.hostHeadless,
    ),
    direction: BudgetDirection.values.firstWhere(
      (d) => d.name == json['direction'],
      orElse: () => BudgetDirection.atMost,
    ),
    limit: asDoubleOr(json['limit'], 0),
    regressionTolerancePercent: json['regressionTolerancePercent'] == null
        ? null
        : asDoubleOr(json['regressionTolerancePercent'], 0),
    maxAgeMs: json['maxAgeMs'] == null ? null : asIntOr(json['maxAgeMs'], 0),
  );
}

class PerformanceBudgetViolation {
  const PerformanceBudgetViolation({
    required this.metricName,
    required this.kind,
    required this.detail,
  });

  final String metricName;
  final PerformanceBudgetViolationKind kind;
  final String detail;

  @override
  String toString() => '[$metricName] ${kind.name}: $detail';
}

class PerformanceBudgetResult {
  const PerformanceBudgetResult({required this.violations});

  final List<PerformanceBudgetViolation> violations;

  bool get passed => violations.isEmpty;
}

/// Checks [measurements] against [policies]. Each policy fails on at most
/// one [PerformanceBudgetViolation] (checked in the order: missing, wrong
/// source, stale, over budget, regression) — stops at the first that
/// applies rather than piling up redundant complaints about one metric.
PerformanceBudgetResult checkPerformanceBudgets({
  required List<PerformanceBudgetMetric> measurements,
  required List<BudgetPolicy> policies,
  List<PerformanceBudgetMetric> baseline = const [],
  int? nowMs,
}) {
  final byName = {for (final m in measurements) m.name: m};
  final baselineByName = {for (final m in baseline) m.name: m};
  final violations = <PerformanceBudgetViolation>[];

  for (final policy in policies) {
    final measured = byName[policy.metricName];
    if (measured == null) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: policy.metricName,
          kind: PerformanceBudgetViolationKind.missingMeasurement,
          detail: 'no measurement provided for this metric',
        ),
      );
      continue;
    }
    if (measured.source != policy.requiredSource) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: policy.metricName,
          kind: PerformanceBudgetViolationKind.wrongSource,
          detail:
              'policy requires ${policy.requiredSource.name}, '
              'got ${measured.source.name}',
        ),
      );
      continue;
    }
    if (policy.maxAgeMs != null &&
        nowMs != null &&
        measured.recordedAtMs != null) {
      final age = nowMs - measured.recordedAtMs!;
      if (age > policy.maxAgeMs!) {
        violations.add(
          PerformanceBudgetViolation(
            metricName: policy.metricName,
            kind: PerformanceBudgetViolationKind.staleMeasurement,
            detail: 'measurement is ${age}ms old, max allowed ${policy.maxAgeMs}ms',
          ),
        );
        continue;
      }
    }
    final overBudget = policy.direction == BudgetDirection.atMost
        ? measured.value > policy.limit
        : measured.value < policy.limit;
    if (overBudget) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: policy.metricName,
          kind: PerformanceBudgetViolationKind.budgetExceeded,
          detail:
              'measured ${measured.value}${measured.unit}, '
              '${policy.direction == BudgetDirection.atMost ? "limit" : "floor"} '
              '${policy.limit}${measured.unit}',
        ),
      );
      continue;
    }
    final base = baselineByName[policy.metricName];
    final tolerance = policy.regressionTolerancePercent;
    if (base != null && tolerance != null) {
      final isRegression = policy.direction == BudgetDirection.atMost
          ? measured.value > base.value * (1 + tolerance / 100)
          : measured.value < base.value * (1 - tolerance / 100);
      if (isRegression) {
        violations.add(
          PerformanceBudgetViolation(
            metricName: policy.metricName,
            kind: PerformanceBudgetViolationKind.regression,
            detail:
                'measured ${measured.value}${measured.unit} vs baseline '
                '${base.value}${measured.unit} (tolerance $tolerance%)',
          ),
        );
      }
    }
  }

  return PerformanceBudgetResult(violations: violations);
}
