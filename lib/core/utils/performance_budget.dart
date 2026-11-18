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
///
/// [emulator] is an Android emulator run: kept distinct from [realDevice]
/// because a policy that requires physical-device evidence must reject it.
enum MeasurementSource { hostHeadless, realDevice, emulator }

/// Whether a budget's [BudgetPolicy.limit] is a ceiling or a floor.
enum BudgetDirection { atMost, atLeast }

/// Why a [BudgetPolicy] failed in [checkPerformanceBudgets]. One policy yields
/// at most one violation, so these are mutually exclusive per metric.
enum PerformanceBudgetViolationKind {
  /// No measurement with the policy's `metricName` was supplied. (Also used by
  /// [WorkloadPerformanceBudget.evaluate] when a report has too few frames.)
  missingMeasurement,

  /// The measurement's [MeasurementSource] differs from the policy's
  /// `requiredSource`; no value comparison is attempted.
  wrongSource,

  /// The measurement is older than the policy's `maxAgeMs`.
  staleMeasurement,

  /// The value is past the policy's `limit` (above it for
  /// [BudgetDirection.atMost], below it for [BudgetDirection.atLeast]).
  budgetExceeded,

  /// The value is within the hard limit but worse than the baseline by more
  /// than the policy's `regressionTolerancePercent`.
  regression,
}

/// One measured value — e.g. an allocation-reduction percentage from
/// `tool/object_pool_benchmark.dart`, or a real-device app-boot wall time.
class PerformanceBudgetMetric {
  /// [name] is matched against [BudgetPolicy.metricName]. [unit] is only a
  /// display suffix in violation details; it takes no part in comparisons.
  const PerformanceBudgetMetric({
    required this.name,
    required this.source,
    required this.value,
    required this.unit,
    this.recordedAtMs,
  });

  /// Key a [BudgetPolicy] uses to find this metric. If a measurement list
  /// repeats a name, [checkPerformanceBudgets] uses the last one.
  final String name;

  /// Where the value came from; compared with [BudgetPolicy.requiredSource].
  final MeasurementSource source;

  /// The measured number, in [unit].
  final double value;

  /// Display unit (e.g. `ms`, `%`) appended to values in violation details.
  final String unit;

  /// When this value was actually measured. Required for
  /// [BudgetPolicy.maxAgeMs] staleness checks (mainly meaningful for a
  /// [MeasurementSource.realDevice] metric carried forward in a committed
  /// baseline between real smoke-test runs); `null` for a metric always
  /// re-measured fresh in the same process (e.g. a headless benchmark).
  final int? recordedAtMs;

  /// JSON form read back by [PerformanceBudgetMetric.fromJson]; `recordedAtMs`
  /// is omitted when it is `null`.
  Map<String, Object?> toJson() => {
    'name': name,
    'source': source.name,
    'value': value,
    'unit': unit,
    if (recordedAtMs != null) 'recordedAtMs': recordedAtMs,
  };

  /// Tolerant parse of [toJson] output. A missing or wrong-typed field falls
  /// back to a default instead of throwing: `name`/`unit` to `''`, `value` to
  /// `0`, and an unknown or missing `source` to [MeasurementSource.hostHeadless].
  /// `recordedAtMs` stays `null` when absent.
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
  /// [metricName] picks the measurement to check, [requiredSource] is the only
  /// source accepted for it, and [limit] is its ceiling or floor per
  /// [direction]. The optional [regressionTolerancePercent] and [maxAgeMs]
  /// enable the baseline and staleness checks.
  const BudgetPolicy({
    required this.metricName,
    required this.requiredSource,
    required this.direction,
    required this.limit,
    this.regressionTolerancePercent,
    this.maxAgeMs,
  });

  /// Name of the [PerformanceBudgetMetric] this rule applies to.
  final String metricName;

  /// The only [MeasurementSource] that satisfies this rule.
  final MeasurementSource requiredSource;

  /// Whether [limit] is a ceiling ([BudgetDirection.atMost]) or a floor.
  final BudgetDirection direction;

  /// Boundary value, in the metric's own unit. A value exactly equal to it
  /// passes: only strictly above (ceiling) or strictly below (floor) fails.
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

  /// Tolerant parse from decoded JSON. Missing or invalid fields fall back to
  /// `metricName: ''`, `requiredSource: hostHeadless`, `direction: atMost` and
  /// `limit: 0`, so a malformed rule is not rejected here, it just becomes a
  /// strict one; validate the source file if that matters.
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

/// One failed budget rule, reported by [checkPerformanceBudgets] or
/// [WorkloadPerformanceBudget.evaluate].
class PerformanceBudgetViolation {
  /// [detail] is a human-readable explanation with the measured numbers.
  const PerformanceBudgetViolation({
    required this.metricName,
    required this.kind,
    required this.detail,
  });

  /// The metric (or workload-derived metric name) that failed.
  final String metricName;

  /// Which check failed.
  final PerformanceBudgetViolationKind kind;

  /// Human-readable explanation, including measured value and limit.
  final String detail;

  @override
  String toString() => '[$metricName] ${kind.name}: $detail';
}

/// Outcome of a budget check: the list of failed rules.
class PerformanceBudgetResult {
  /// An empty [violations] list means every checked rule passed.
  const PerformanceBudgetResult({required this.violations});

  /// Failed rules, in policy order (one per failing policy at most).
  final List<PerformanceBudgetViolation> violations;

  /// `true` when [violations] is empty.
  bool get passed => violations.isEmpty;
}

/// Checks [measurements] against [policies]. Each policy fails on at most
/// one [PerformanceBudgetViolation] (checked in the order: missing, wrong
/// source, stale, over budget, regression) — stops at the first that
/// applies rather than piling up redundant complaints about one metric.
///
/// The staleness check runs only when the policy's `maxAgeMs`, [nowMs] and the
/// metric's `recordedAtMs` are all non-null, and fails only when the age is
/// strictly greater than `maxAgeMs`. The regression check runs only when a
/// [baseline] metric with the same name exists and the policy sets a
/// tolerance, and is skipped for a metric that already exceeded its limit.
/// The baseline's source is not compared.
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
            detail:
                'measurement is ${age}ms old, max allowed ${policy.maxAgeMs}ms',
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

/// Evaluates integration test frame workload reports against configurable budgets (ENH-102).
class WorkloadPerformanceBudget {
  /// Defaults: p95 of at most 64 ms, at most 50% slow frames, and at least 30
  /// frames in the report.
  const WorkloadPerformanceBudget({
    required this.workloadName,
    this.maxP95Ms = 64.0,
    this.maxSlowFramePercent = 50.0,
    this.minFrames = 30,
  });

  /// Prefix of the metric names this budget reports, e.g. `<name>_p95_ms`.
  final String workloadName;

  /// Ceiling for the report's p95 value, in milliseconds.
  final double maxP95Ms;

  /// Ceiling for the report's slow-frame share, in percent (0-100).
  final double maxSlowFramePercent;

  /// Fewer frames than this fails, so an empty or truncated run cannot pass.
  final int minFrames;

  /// Checks a decoded frame-workload [report] with the keys `frameCount`,
  /// `maxBuildRasterMs.p95` and `slowFramePercent`.
  ///
  /// A missing or wrong-typed key is read as `0`, so a report without p95 or
  /// slow-frame data passes those two checks; only the `minFrames` check
  /// catches an empty report. Limits are strict: a value equal to its ceiling
  /// passes. Too few frames is reported as
  /// [PerformanceBudgetViolationKind.missingMeasurement] under
  /// `<workloadName>_frame_count`; the other two as
  /// [PerformanceBudgetViolationKind.budgetExceeded].
  PerformanceBudgetResult evaluate(Map<String, Object?> report) {
    final violations = <PerformanceBudgetViolation>[];
    final frameCount = asIntOr(report['frameCount'], 0);
    if (frameCount < minFrames) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: '${workloadName}_frame_count',
          kind: PerformanceBudgetViolationKind.missingMeasurement,
          detail: 'measured $frameCount frames, required at least $minFrames',
        ),
      );
    }

    final maxBuildRaster = report['maxBuildRasterMs'];
    final p95 = maxBuildRaster is Map
        ? asDoubleOr(maxBuildRaster['p95'], 0.0)
        : 0.0;
    if (p95 > maxP95Ms) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: '${workloadName}_p95_ms',
          kind: PerformanceBudgetViolationKind.budgetExceeded,
          detail:
              'measured ${p95.toStringAsFixed(2)}ms, limit ${maxP95Ms.toStringAsFixed(2)}ms',
        ),
      );
    }

    final slowPercent = asDoubleOr(report['slowFramePercent'], 0.0);
    if (slowPercent > maxSlowFramePercent) {
      violations.add(
        PerformanceBudgetViolation(
          metricName: '${workloadName}_slow_frame_percent',
          kind: PerformanceBudgetViolationKind.budgetExceeded,
          detail:
              'measured ${slowPercent.toStringAsFixed(1)}%, limit ${maxSlowFramePercent.toStringAsFixed(1)}%',
        ),
      );
    }

    return PerformanceBudgetResult(violations: violations);
  }

  /// Turns the same [report] keys as [evaluate] into two metrics,
  /// `<workloadName>_p95_ms` (ms) and `<workloadName>_slow_frame_percent` (%),
  /// so they can be fed to [checkPerformanceBudgets] against policies and a
  /// baseline. Missing keys become `0`; the frame count is not checked here.
  List<PerformanceBudgetMetric> extractMetrics(
    Map<String, Object?> report, {
    required MeasurementSource source,
    int? recordedAtMs,
  }) {
    final maxBuildRaster = report['maxBuildRasterMs'];
    final p95 = maxBuildRaster is Map
        ? asDoubleOr(maxBuildRaster['p95'], 0.0)
        : 0.0;
    final slowPercent = asDoubleOr(report['slowFramePercent'], 0.0);
    return [
      PerformanceBudgetMetric(
        name: '${workloadName}_p95_ms',
        source: source,
        value: p95,
        unit: 'ms',
        recordedAtMs: recordedAtMs,
      ),
      PerformanceBudgetMetric(
        name: '${workloadName}_slow_frame_percent',
        source: source,
        value: slowPercent,
        unit: '%',
        recordedAtMs: recordedAtMs,
      ),
    ];
  }
}
