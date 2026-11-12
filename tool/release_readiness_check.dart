// FEAT-206: read-only pre-tag checklist. Never tags, pushes or publishes.
// Usage: dart run tool/release_readiness_check.dart [--no-ci]
import 'dart:io';

enum CheckStatus { pass, fail, warn, skip }

class CheckResult {
  const CheckResult(this.name, this.status, [this.detail = '']);
  final String name;
  final CheckStatus status;
  final String detail;
}

String? readPubspecVersion(String yaml) => RegExp(
  r'^version:\s*([^\s+]+)',
  multiLine: true,
).firstMatch(yaml)?.group(1);

/// First `## x.y.z` heading in a CHANGELOG, or null.
String? latestChangelogVersion(String changelog) => RegExp(
  r'^##\s+(\d+\.\d+\.\d+)\s*$',
  multiLine: true,
).firstMatch(changelog)?.group(1);

/// Pure evaluation over already-collected facts, so it is unit-testable.
List<CheckResult> evaluateReadiness({
  required String? pubspecVersion,
  required String? changelogVersion,
  required String? exampleLockVersion,
  required Set<String> tags,
  required bool treeClean,
  required bool syncedWithOrigin,
  required bool apiGateClean,
  required bool? ciGreen,
  required List<String> openHighPriorityTasks,
}) {
  final v = pubspecVersion;
  return [
    CheckResult(
      'pubspec version matches top CHANGELOG entry',
      v != null && v == changelogVersion ? CheckStatus.pass : CheckStatus.fail,
      'pubspec=$v changelog=$changelogVersion',
    ),
    CheckResult(
      'example/pubspec.lock matches package version',
      exampleLockVersion == v ? CheckStatus.pass : CheckStatus.fail,
      'lock=$exampleLockVersion pubspec=$v',
    ),
    CheckResult(
      'tag v$v does not exist yet',
      v != null && !tags.contains('v$v') ? CheckStatus.pass : CheckStatus.fail,
    ),
    CheckResult(
      'working tree clean',
      treeClean ? CheckStatus.pass : CheckStatus.fail,
    ),
    CheckResult(
      'main in sync with origin/main',
      syncedWithOrigin ? CheckStatus.pass : CheckStatus.fail,
    ),
    CheckResult(
      'public API gate clean',
      apiGateClean ? CheckStatus.pass : CheckStatus.fail,
    ),
    CheckResult(
      'latest CI run on HEAD is green (all jobs)',
      ciGreen == null
          ? CheckStatus.skip
          : (ciGreen ? CheckStatus.pass : CheckStatus.fail),
      ciGreen == null ? 'gh unavailable or --no-ci' : '',
    ),
    CheckResult(
      'no open P0/P1 task in doc/task/todo',
      openHighPriorityTasks.isEmpty ? CheckStatus.pass : CheckStatus.warn,
      openHighPriorityTasks.join(', '),
    ),
  ];
}

/// Task ids whose front matter says `priority: P0` or `P1`.
List<String> highPriorityTaskIds(Map<String, String> filesByName) => [
  for (final e in filesByName.entries)
    if (RegExp(r'^priority:\s*P[01]\b', multiLine: true).hasMatch(e.value))
      e.key.split('-').take(2).join('-'),
];

Future<String?> _run(String exe, List<String> args) async {
  try {
    final r = await Process.run(exe, args);
    return r.exitCode == 0 ? (r.stdout as String).trim() : null;
  } on ProcessException {
    return null;
  }
}

String? _lockVersion(String lock) => RegExp(
  r'roy_casual_kit:[\s\S]*?version:\s*"([^"]+)"',
).firstMatch(lock)?.group(1);

Future<void> main(List<String> args) async {
  final noCi = args.contains('--no-ci');
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final changelog = File('CHANGELOG.md').readAsStringSync();
  final lockFile = File('example/pubspec.lock');
  final tags = ((await _run('git', ['tag', '-l'])) ?? '')
      .split('\n')
      .where((t) => t.isNotEmpty)
      .toSet();
  final status = await _run('git', ['status', '--porcelain']);
  final head = await _run('git', ['rev-parse', 'HEAD']);
  final origin = await _run('git', ['rev-parse', 'origin/main']);
  final api = await Process.run('dart', [
    'run',
    'tool/api_compatibility.dart',
    'check',
  ]);

  bool? ci;
  if (!noCi && head != null) {
    final out = await _run('gh', [
      'run',
      'list',
      '--workflow=ci.yml',
      '--commit',
      head,
      '--limit',
      '1',
      '--json',
      'status,conclusion',
      '--jq',
      '.[0] | "\\(.status) \\(.conclusion)"',
    ]);
    ci = out == null || out.isEmpty ? null : out == 'completed success';
  }

  final tasks = <String, String>{};
  final todo = Directory('doc/task/todo');
  if (todo.existsSync()) {
    for (final f in todo.listSync().whereType<File>()) {
      tasks[f.uri.pathSegments.last] = f.readAsStringSync();
    }
  }

  final results = evaluateReadiness(
    pubspecVersion: readPubspecVersion(pubspec),
    changelogVersion: latestChangelogVersion(changelog),
    exampleLockVersion: lockFile.existsSync()
        ? _lockVersion(lockFile.readAsStringSync())
        : null,
    tags: tags,
    treeClean: status != null && status.isEmpty,
    syncedWithOrigin: head != null && head == origin,
    apiGateClean: api.exitCode == 0,
    ciGreen: ci,
    openHighPriorityTasks: highPriorityTaskIds(tasks),
  );

  var failed = false;
  for (final r in results) {
    final mark = switch (r.status) {
      CheckStatus.pass => 'PASS',
      CheckStatus.fail => 'FAIL',
      CheckStatus.warn => 'WARN',
      CheckStatus.skip => 'SKIP',
    };
    if (r.status == CheckStatus.fail) failed = true;
    stdout.writeln(
      '[$mark] ${r.name}${r.detail.isEmpty ? '' : ' — ${r.detail}'}',
    );
  }
  stdout.writeln(
    failed
        ? 'NOT READY: fix FAIL items above. This tool never tags or publishes.'
        : 'Ready by these checks. Tag/publish still needs an explicit request.',
  );
  exitCode = failed ? 1 : 0;
}
