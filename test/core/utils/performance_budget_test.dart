import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/performance_budget.dart';

BudgetPolicy _policy({
  String name = 'metric_a',
  MeasurementSource source = MeasurementSource.hostHeadless,
  BudgetDirection direction = BudgetDirection.atMost,
  double limit = 100,
  double? regressionTolerancePercent,
  int? maxAgeMs,
}) => BudgetPolicy(
  metricName: name,
  requiredSource: source,
  direction: direction,
  limit: limit,
  regressionTolerancePercent: regressionTolerancePercent,
  maxAgeMs: maxAgeMs,
);

PerformanceBudgetMetric _metric({
  String name = 'metric_a',
  MeasurementSource source = MeasurementSource.hostHeadless,
  double value = 50,
  String unit = 'ms',
  int? recordedAtMs,
}) => PerformanceBudgetMetric(
  name: name,
  source: source,
  value: value,
  unit: unit,
  recordedAtMs: recordedAtMs,
);

void main() {
  group('checkPerformanceBudgets', () {
    test('không đo metric mà policy yêu cầu -> missingMeasurement, fail', () {
      final result = checkPerformanceBudgets(
        measurements: const [],
        policies: [_policy()],
      );
      expect(result.passed, isFalse);
      expect(
        result.violations.single.kind,
        PerformanceBudgetViolationKind.missingMeasurement,
      );
    });

    test('đúng budget, đúng source -> pass, không violation', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 50)],
        policies: [_policy(limit: 100)],
      );
      expect(result.passed, isTrue);
      expect(result.violations, isEmpty);
    });

    test('vượt budget atMost -> budgetExceeded', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 150)],
        policies: [_policy(limit: 100, direction: BudgetDirection.atMost)],
      );
      expect(result.passed, isFalse);
      expect(
        result.violations.single.kind,
        PerformanceBudgetViolationKind.budgetExceeded,
      );
    });

    test('atLeast: dưới sàn -> budgetExceeded', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 30)],
        policies: [_policy(limit: 50, direction: BudgetDirection.atLeast)],
      );
      expect(result.passed, isFalse);
      expect(
        result.violations.single.kind,
        PerformanceBudgetViolationKind.budgetExceeded,
      );
    });

    test('atLeast: đạt hoặc vượt sàn -> pass', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 60)],
        policies: [_policy(limit: 50, direction: BudgetDirection.atLeast)],
      );
      expect(result.passed, isTrue);
    });

    test('source đo được khác source policy yêu cầu -> wrongSource, không '
        'coi số đo host là bằng chứng device', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(source: MeasurementSource.hostHeadless)],
        policies: [_policy(source: MeasurementSource.realDevice)],
      );
      expect(result.passed, isFalse);
      expect(
        result.violations.single.kind,
        PerformanceBudgetViolationKind.wrongSource,
      );
    });

    test(
      'regression: tệ hơn baseline quá tolerance dù vẫn trong budget cứng',
      () {
        final result = checkPerformanceBudgets(
          measurements: [_metric(value: 90)],
          baseline: [_metric(value: 50)],
          policies: [_policy(limit: 100, regressionTolerancePercent: 20)],
        );
        expect(result.passed, isFalse);
        expect(
          result.violations.single.kind,
          PerformanceBudgetViolationKind.regression,
        );
      },
    );

    test('trong tolerance so với baseline -> không phải regression', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 55)],
        baseline: [_metric(value: 50)],
        policies: [_policy(limit: 100, regressionTolerancePercent: 20)],
      );
      expect(result.passed, isTrue);
    });

    test(
      'không có baseline -> bỏ qua regression check, chỉ xét budget cứng',
      () {
        final result = checkPerformanceBudgets(
          measurements: [_metric(value: 90)],
          policies: [_policy(limit: 100, regressionTolerancePercent: 20)],
        );
        expect(result.passed, isTrue);
      },
    );

    test('measurement quá cũ so với maxAgeMs -> staleMeasurement', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 10, recordedAtMs: 1000)],
        policies: [_policy(limit: 100, maxAgeMs: 500)],
        nowMs: 2000,
      );
      expect(result.passed, isFalse);
      expect(
        result.violations.single.kind,
        PerformanceBudgetViolationKind.staleMeasurement,
      );
    });

    test('measurement đủ mới trong maxAgeMs -> không stale', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(value: 10, recordedAtMs: 1900)],
        policies: [_policy(limit: 100, maxAgeMs: 500)],
        nowMs: 2000,
      );
      expect(result.passed, isTrue);
    });

    test(
      'maxAgeMs đặt nhưng thiếu nowMs hoặc recordedAtMs -> bỏ qua stale check, không throw',
      () {
        final result = checkPerformanceBudgets(
          measurements: [_metric(value: 10)],
          policies: [_policy(limit: 100, maxAgeMs: 500)],
        );
        expect(result.passed, isTrue);
      },
    );

    test('nhiều policy độc lập -> gom đủ mọi violation', () {
      final result = checkPerformanceBudgets(
        measurements: [_metric(name: 'a', value: 200)],
        policies: [
          _policy(name: 'a', limit: 100),
          _policy(name: 'b', limit: 100),
        ],
      );
      expect(result.violations, hasLength(2));
      expect(
        result.violations.map((v) => v.metricName),
        containsAll(['a', 'b']),
      );
    });
  });

  group('PerformanceBudgetMetric JSON round-trip', () {
    test('toJson/fromJson giữ nguyên dữ liệu', () {
      const metric = PerformanceBudgetMetric(
        name: 'boot_ms',
        source: MeasurementSource.realDevice,
        value: 1234.5,
        unit: 'ms',
        recordedAtMs: 999,
      );
      final roundTripped = PerformanceBudgetMetric.fromJson(metric.toJson());
      expect(roundTripped.name, metric.name);
      expect(roundTripped.source, metric.source);
      expect(roundTripped.value, metric.value);
      expect(roundTripped.unit, metric.unit);
      expect(roundTripped.recordedAtMs, metric.recordedAtMs);
    });

    test('fromJson trên map thiếu field -> fallback an toàn, không throw', () {
      final metric = PerformanceBudgetMetric.fromJson(const {});
      expect(metric.name, '');
      expect(metric.source, MeasurementSource.hostHeadless);
      expect(metric.value, 0);
      expect(metric.recordedAtMs, isNull);
    });
  });

  group('BudgetPolicy JSON round-trip', () {
    test('fromJson đọc đúng mọi field', () {
      final policy = BudgetPolicy.fromJson(const {
        'metricName': 'boot_ms',
        'requiredSource': 'realDevice',
        'direction': 'atLeast',
        'limit': 42.0,
        'regressionTolerancePercent': 15.0,
        'maxAgeMs': 86400000,
      });
      expect(policy.metricName, 'boot_ms');
      expect(policy.requiredSource, MeasurementSource.realDevice);
      expect(policy.direction, BudgetDirection.atLeast);
      expect(policy.limit, 42.0);
      expect(policy.regressionTolerancePercent, 15.0);
      expect(policy.maxAgeMs, 86400000);
    });

    test('fromJson trên map thiếu field -> fallback an toàn, không throw', () {
      final policy = BudgetPolicy.fromJson(const {});
      expect(policy.metricName, '');
      expect(policy.requiredSource, MeasurementSource.hostHeadless);
      expect(policy.direction, BudgetDirection.atMost);
      expect(policy.limit, 0);
      expect(policy.regressionTolerancePercent, isNull);
      expect(policy.maxAgeMs, isNull);
    });
  });

  group('WorkloadPerformanceBudget (ENH-102)', () {
    const budget = WorkloadPerformanceBudget(
      workloadName: 'demo_workload',
      maxP95Ms: 32.0,
      maxSlowFramePercent: 20.0,
      minFrames: 50,
    );

    final validReport = {
      'frameCount': 100,
      'maxBuildRasterMs': {'p50': 8.0, 'p95': 14.5, 'p99': 18.0},
      'slowFramePercent': 5.0,
    };

    test('report hợp lệ nằm trong ngưỡng -> pass', () {
      final result = budget.evaluate(validReport);
      expect(result.passed, isTrue);
      expect(result.violations, isEmpty);
    });

    test('frameCount quá ít (< minFrames) -> missingMeasurement violation', () {
      final result = budget.evaluate({
        'frameCount': 10,
        'maxBuildRasterMs': {'p95': 10.0},
        'slowFramePercent': 0.0,
      });
      expect(result.passed, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.kind == PerformanceBudgetViolationKind.missingMeasurement &&
              v.metricName == 'demo_workload_frame_count',
        ),
        isTrue,
      );
    });

    test('p95 vượt ngưỡng maxP95Ms -> budgetExceeded violation', () {
      final result = budget.evaluate({
        'frameCount': 60,
        'maxBuildRasterMs': {'p95': 45.0},
        'slowFramePercent': 5.0,
      });
      expect(result.passed, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.kind == PerformanceBudgetViolationKind.budgetExceeded &&
              v.metricName == 'demo_workload_p95_ms',
        ),
        isTrue,
      );
    });

    test('slowFramePercent vượt ngưỡng -> budgetExceeded violation', () {
      final result = budget.evaluate({
        'frameCount': 60,
        'maxBuildRasterMs': {'p95': 15.0},
        'slowFramePercent': 35.0,
      });
      expect(result.passed, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.kind == PerformanceBudgetViolationKind.budgetExceeded &&
              v.metricName == 'demo_workload_slow_frame_percent',
        ),
        isTrue,
      );
    });

    test('extractMetrics trích xuất đúng PerformanceBudgetMetric', () {
      final metrics = budget.extractMetrics(
        validReport,
        source: MeasurementSource.realDevice,
        recordedAtMs: 123456,
      );
      expect(metrics, hasLength(2));
      expect(metrics[0].name, 'demo_workload_p95_ms');
      expect(metrics[0].value, 14.5);
      expect(metrics[0].unit, 'ms');
      expect(metrics[0].source, MeasurementSource.realDevice);
      expect(metrics[0].recordedAtMs, 123456);

      expect(metrics[1].name, 'demo_workload_slow_frame_percent');
      expect(metrics[1].value, 5.0);
      expect(metrics[1].unit, '%');
    });
  });
}
