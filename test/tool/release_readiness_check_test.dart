import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_readiness_check.dart';

List<CheckResult> eval({
  String? pubspec = '0.7.0',
  String? changelog = '0.7.0',
  String? lock = '0.7.0',
  Set<String> tags = const {'v0.6.8'},
  bool clean = true,
  bool synced = true,
  bool api = true,
  bool? ci = true,
  List<String> tasks = const [],
}) => evaluateReadiness(
  pubspecVersion: pubspec,
  changelogVersion: changelog,
  exampleLockVersion: lock,
  tags: tags,
  treeClean: clean,
  syncedWithOrigin: synced,
  apiGateClean: api,
  ciGreen: ci,
  openHighPriorityTasks: tasks,
);

Iterable<CheckResult> failing(List<CheckResult> r) =>
    r.where((c) => c.status == CheckStatus.fail);

void main() {
  test('đủ điều kiện: không FAIL', () {
    expect(failing(eval()), isEmpty);
  });

  test('version pubspec lệch CHANGELOG, lock, hoặc tag đã tồn tại -> FAIL', () {
    expect(failing(eval(changelog: '0.6.8')), hasLength(1));
    expect(failing(eval(lock: '0.6.8')), hasLength(1));
    expect(failing(eval(tags: {'v0.7.0'})), hasLength(1));
  });

  test('cây bẩn, chưa đồng bộ origin, API gate, CI đỏ -> FAIL từng cái', () {
    expect(failing(eval(clean: false)), hasLength(1));
    expect(failing(eval(synced: false)), hasLength(1));
    expect(failing(eval(api: false)), hasLength(1));
    expect(failing(eval(ci: false)), hasLength(1));
  });

  test('CI không đọc được thì SKIP, task P1 chỉ WARN, không chặn', () {
    final r = eval(ci: null, tasks: ['FEAT-200']);
    expect(failing(r), isEmpty);
    expect(r.any((c) => c.status == CheckStatus.skip), isTrue);
    expect(r.any((c) => c.status == CheckStatus.warn), isTrue);
  });

  test('parse version/CHANGELOG/task', () {
    expect(readPubspecVersion('name: x\nversion: 1.2.3+4\n'), '1.2.3');
    expect(
      latestChangelogVersion('# Log\n\n## 0.6.8\n- a\n## 0.6.7\n'),
      '0.6.8',
    );
    expect(latestChangelogVersion('no headings'), isNull);
    expect(
      highPriorityTaskIds({
        'FEAT-200-x.md': 'id: FEAT-200\npriority: P1\n',
        'FEAT-201-y.md': 'priority: P2\n',
        'BUG-9-z.md': 'priority: P0\n',
      }),
      ['FEAT-200', 'BUG-9'],
    );
  });
}
