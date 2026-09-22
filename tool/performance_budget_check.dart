// Performance Budget CI gate (FEAT-80).
//
// Checks frame-time/allocation/asset-load metrics against a committed
// budget policy (tool/performance_budget_policy.json), with regression
// detection against a committed baseline (tool/performance_budget_baseline.json).
//
// Two measurement sources, both real, never fabricated:
// - `hostHeadless`: re-measured fresh every run by calling this repo's own
//   `runPooled`/`runUnpooled` (tool/object_pool_benchmark.dart, FEAT-48) —
//   the allocation-reduction percentage this benchmark reports is
//   deterministic and reproducible on any host/CI runner.
// - `realDevice`: NOT reproducible headless. Only measured when `--device=`
//   names a real, currently-connected device — this runs
//   `example/integration_test/app_boot_test.dart` on it and times real
//   wall-clock boot time. Without `--device=`, `check` falls back to
//   whatever `realDevice` value is already committed in the baseline
//   (from the last real smoke-test run) rather than pretending a fresh
//   number exists — this is why every metric records its own
//   `recordedAtMs`, and why a policy can set `maxAgeMs` to force a
//   periodic re-run (a stale device number is a `staleMeasurement`
//   violation, not a silent pass).
//
// `--deviceMetricName=` (default `example_app_boot_wall_ms`) is the metric
// name the device measurement is recorded under. A CI-emulator run is NOT
// the same population as a real physical device — an emulator's cold-boot
// wall time is routinely 5-10x a real device's, so `.github/workflows/
// benchmark.yml` passes a distinct `example_app_boot_wall_ms_emulator`
// here rather than writing into the physical-device metric name
// `tool/performance_budget_policy.json` actually gates on. Only a name
// with a matching policy entry is ever checked — an emulator name with no
// policy entry is recorded in the baseline (for visibility) but never
// gates anything.
//
// Usage:
//   dart run tool/performance_budget_check.dart check [--device=<id>]
//     [--deviceMetricName=example_app_boot_wall_ms]
//     [--policies=tool/performance_budget_policy.json]
//     [--baseline=tool/performance_budget_baseline.json]
//   dart run tool/performance_budget_check.dart snapshot [--device=<id>]
//     [--deviceMetricName=example_app_boot_wall_ms]
//     [--baseline=tool/performance_budget_baseline.json]
//
// `check` never writes the baseline file — only `snapshot` does, mirroring
// tool/api_compatibility.dart's check/snapshot split.

import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/performance_budget.dart';

import 'object_pool_benchmark.dart' show runPooled, runUnpooled;

const _defaultPolicyPath = 'tool/performance_budget_policy.json';
const _defaultBaselinePath = 'tool/performance_budget_baseline.json';
const _defaultDeviceMetricName = 'example_app_boot_wall_ms';

Future<void> main(List<String> args) async {
  String? command;
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      command ??= arg;
      continue;
    }
    final eq = arg.indexOf('=');
    if (eq == -1) {
      options[arg.substring(2)] = 'true';
    } else {
      options[arg.substring(2, eq)] = arg.substring(eq + 1);
    }
  }
  command ??= 'check';
  final policyPath = options['policies'] ?? _defaultPolicyPath;
  final baselinePath = options['baseline'] ?? _defaultBaselinePath;
  final deviceId = options['device'];
  final deviceMetricName =
      options['deviceMetricName'] ?? _defaultDeviceMetricName;

  switch (command) {
    case 'check':
      await _check(
        policyPath: policyPath,
        baselinePath: baselinePath,
        deviceId: deviceId,
        deviceMetricName: deviceMetricName,
      );
    case 'snapshot':
      await _snapshot(
        baselinePath: baselinePath,
        deviceId: deviceId,
        deviceMetricName: deviceMetricName,
      );
    default:
      stderr.writeln(
        'Usage: dart run tool/performance_budget_check.dart '
        '[check|snapshot] [--device=<id>] [--deviceMetricName=<name>] '
        '[--policies=<path>] [--baseline=<path>]',
      );
      exitCode = 64;
  }
}

List<PerformanceBudgetMetric> _measureHostHeadless() {
  const frames = 600;
  const spawnPerFrame = 10;
  const lifetimeFrames = 15;
  const capacity = 200;
  final pooled = runPooled(
    frames: frames,
    spawnPerFrame: spawnPerFrame,
    lifetimeFrames: lifetimeFrames,
    capacity: capacity,
  );
  final unpooled = runUnpooled(
    frames: frames,
    spawnPerFrame: spawnPerFrame,
    lifetimeFrames: lifetimeFrames,
  );
  final reductionPercent = unpooled.totalAllocations == 0
      ? 0.0
      : (1 - pooled.totalAllocations / unpooled.totalAllocations) * 100;
  return [
    PerformanceBudgetMetric(
      name: 'object_pool_allocation_reduction_percent',
      source: MeasurementSource.hostHeadless,
      value: reductionPercent,
      unit: '%',
    ),
    PerformanceBudgetMetric(
      name: 'object_pool_pooled_elapsed_us',
      source: MeasurementSource.hostHeadless,
      value: pooled.elapsed.inMicroseconds.toDouble(),
      unit: 'us',
    ),
  ];
}

/// Runs the real device-boot integration test on [deviceId] and returns its
/// real wall-clock duration as a [MeasurementSource.realDevice] metric, or
/// `null` if the run itself failed (never fabricates a number on failure).
Future<PerformanceBudgetMetric?> _measureRealDevice(
  String deviceId,
  String metricName,
) async {
  final stopwatch = Stopwatch()..start();
  final result = await Process.run('flutter', [
    'test',
    'integration_test/app_boot_test.dart',
    '-d',
    deviceId,
    '--dart-define=E2E_TEST=true',
    '--plain-name=app boots to HomeScreen',
  ], workingDirectory: 'example');
  stopwatch.stop();
  if (result.exitCode != 0) {
    stderr.writeln('Device measurement on $deviceId failed:');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    return null;
  }
  return PerformanceBudgetMetric(
    name: metricName,
    source: MeasurementSource.realDevice,
    value: stopwatch.elapsedMilliseconds.toDouble(),
    unit: 'ms',
    recordedAtMs: DateTime.now().millisecondsSinceEpoch,
  );
}

List<BudgetPolicy> _loadPolicies(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final raw = jsonDecode(file.readAsStringSync()) as List<Object?>;
  return raw
      .whereType<Map>()
      .map((e) => BudgetPolicy.fromJson(Map<String, Object?>.from(e)))
      .toList();
}

List<PerformanceBudgetMetric> _loadMetrics(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final raw = jsonDecode(file.readAsStringSync()) as List<Object?>;
  return raw
      .whereType<Map>()
      .map(
        (e) => PerformanceBudgetMetric.fromJson(Map<String, Object?>.from(e)),
      )
      .toList();
}

Future<void> _check({
  required String policyPath,
  required String baselinePath,
  String? deviceId,
  String deviceMetricName = _defaultDeviceMetricName,
}) async {
  final policies = _loadPolicies(policyPath);
  final baseline = _loadMetrics(baselinePath);
  final fresh = _measureHostHeadless();
  if (deviceId != null) {
    final measured = await _measureRealDevice(deviceId, deviceMetricName);
    if (measured != null) fresh.add(measured);
  }
  // realDevice metrics not freshly re-measured this run fall back to the
  // committed baseline's last real recording (age-gated by maxAgeMs below).
  final measurements = <String, PerformanceBudgetMetric>{
    for (final m in baseline) m.name: m,
    for (final m in fresh) m.name: m,
  }.values.toList();

  final result = checkPerformanceBudgets(
    measurements: measurements,
    policies: policies,
    baseline: baseline,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );

  for (final metric in measurements) {
    stdout.writeln(
      'measured: ${metric.name}=${metric.value}${metric.unit} (${metric.source.name})',
    );
  }
  if (result.passed) {
    stdout.writeln('Performance budget: PASS (${policies.length} policies)');
  } else {
    stderr.writeln('Performance budget: FAIL');
    for (final violation in result.violations) {
      stderr.writeln(' - $violation');
    }
  }
  exitCode = result.passed ? 0 : 1;
}

Future<void> _snapshot({
  required String baselinePath,
  String? deviceId,
  String deviceMetricName = _defaultDeviceMetricName,
}) async {
  final existing = _loadMetrics(baselinePath);
  final now = DateTime.now().millisecondsSinceEpoch;
  final fresh = _measureHostHeadless()
      .map(
        (m) => PerformanceBudgetMetric(
          name: m.name,
          source: m.source,
          value: m.value,
          unit: m.unit,
          recordedAtMs: now,
        ),
      )
      .toList();
  if (deviceId != null) {
    final measured = await _measureRealDevice(deviceId, deviceMetricName);
    if (measured == null) {
      stderr.writeln(
        'Device measurement failed; keeping previous realDevice metrics in baseline.',
      );
    } else {
      fresh.add(measured);
    }
  }
  final merged = <String, PerformanceBudgetMetric>{
    for (final m in existing) m.name: m,
    for (final m in fresh) m.name: m,
  }.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  await File(baselinePath).writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(merged.map((m) => m.toJson()).toList()),
  );
  stdout.writeln('Wrote $baselinePath (${merged.length} metrics)');
}
