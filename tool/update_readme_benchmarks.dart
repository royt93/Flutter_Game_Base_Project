// Rewrites the "## Performance" section of README.md from the committed
// `tool/performance_budget_baseline.json` snapshot — run after
// `dart run tool/performance_budget_check.dart snapshot` (see
// .github/workflows/benchmark.yml). Never fabricates a number: it only
// echoes whatever is already in the baseline file.
//
// Usage:
//   dart run tool/update_readme_benchmarks.dart
//     [--baseline=tool/performance_budget_baseline.json] [--readme=README.md]

import 'dart:convert';
import 'dart:io';

const String startMarker = '<!-- PERF_BENCHMARK_START -->';
const String endMarker = '<!-- PERF_BENCHMARK_END -->';

String _fmtMetricName(String name) => name
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _fmtValue(Object? value, String unit) {
  final v = (value as num).toDouble();
  final rounded = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  return unit == '%' ? '$rounded%' : '$rounded $unit';
}

String _fmtRecordedAt(int recordedAtMs) =>
    DateTime.fromMillisecondsSinceEpoch(recordedAtMs, isUtc: true).toIso8601String().split('T').first;

/// Pure — renders the markdown table body from a decoded baseline JSON list.
/// Exposed for tests; never touches the filesystem.
String renderBenchmarkSection(List<Object?> metrics) {
  final buffer = StringBuffer()
    ..writeln(startMarker)
    ..writeln('| Metric | Value | Source | Recorded |')
    ..writeln('|---|---|---|---|');
  for (final raw in metrics) {
    final m = raw as Map<String, Object?>;
    final name = _fmtMetricName(m['name'] as String);
    final value = _fmtValue(m['value'], m['unit'] as String);
    final source = m['source'] as String;
    final recordedAt = _fmtRecordedAt(m['recordedAtMs'] as int);
    buffer.writeln('| $name | $value | $source | $recordedAt |');
  }
  buffer.write(endMarker);
  return buffer.toString().trimRight();
}

/// Pure — replaces the text strictly between [start]/[end] markers (markers
/// themselves included in the replacement) inside [source] with
/// [replacement]. Throws [FormatException] if either marker is missing, or
/// if [end] doesn't appear after [start].
String replaceBetweenMarkers({
  required String source,
  required String start,
  required String end,
  required String replacement,
}) {
  final startIndex = source.indexOf(start);
  if (startIndex == -1) {
    throw FormatException('Missing marker: $start');
  }
  final endIndex = source.indexOf(end, startIndex);
  if (endIndex == -1) {
    throw FormatException('Missing marker after $start: $end');
  }
  return source.replaceRange(startIndex, endIndex + end.length, replacement);
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('=')) continue;
    final eq = arg.indexOf('=');
    options[arg.substring(2, eq)] = arg.substring(eq + 1);
  }
  return options;
}

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final baselinePath = options['baseline'] ?? 'tool/performance_budget_baseline.json';
  final readmePath = options['readme'] ?? 'README.md';

  final baselineFile = File(baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('Baseline file not found: $baselinePath');
    exitCode = 1;
    return;
  }
  final metrics = jsonDecode(await baselineFile.readAsString()) as List<Object?>;
  final section = renderBenchmarkSection(metrics);

  final readmeFile = File(readmePath);
  final readme = await readmeFile.readAsString();
  final String updated;
  try {
    updated = replaceBetweenMarkers(
      source: readme,
      start: startMarker,
      end: endMarker,
      replacement: section,
    );
  } on FormatException catch (e) {
    stderr.writeln('$readmePath: $e');
    exitCode = 1;
    return;
  }
  await readmeFile.writeAsString(updated);
  stdout.writeln('Updated $readmePath performance section from $baselinePath.');
}
