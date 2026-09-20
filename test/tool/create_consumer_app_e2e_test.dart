@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/create_consumer_app.dart';

// End-to-end: actually shells out to `flutter create` and runs
// `flutter analyze`/`flutter test` on the result — genuinely slow (real
// `flutter create` + `flutter pub get` against this repo via `kitPath`,
// well past what a fast dev loop should eat every run), tagged `slow`
// per dart_test.yaml's own convention so `flutter test --exclude-tags
// slow` skips it. Run explicitly with
// `flutter test test/tool/create_consumer_app_e2e_test.dart` when
// touching the generator.
void main() {
  late Directory workDir;

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('create_consumer_app_e2e_');
  });

  tearDown(() {
    workDir.deleteSync(recursive: true);
  });

  test(
    'generate() thật: flutter create + template + patch pubspec -> analyze/test sạch ngay',
    () async {
      final repoRoot = Directory.current.path;
      final result = await generate(
        name: 'e2e_starter',
        outputDir: workDir.path,
        kitPath: repoRoot,
      );

      expect(Directory(result.path).existsSync(), isTrue);
      expect(File('${result.path}/lib/main.dart').existsSync(), isTrue);
      expect(File('${result.path}/.roy_template_version').existsSync(), isTrue);

      final pubGet = await Process.run('flutter', [
        'pub',
        'get',
      ], workingDirectory: result.path);
      expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');

      final analyze = await Process.run('flutter', [
        'analyze',
      ], workingDirectory: result.path);
      expect(
        analyze.exitCode,
        0,
        reason:
            'flutter analyze phải sạch NGAY sau generate:\n${analyze.stdout}\n${analyze.stderr}',
      );

      final test = await Process.run('flutter', [
        'test',
      ], workingDirectory: result.path);
      expect(
        test.exitCode,
        0,
        reason:
            'flutter test phải pass NGAY sau generate:\n${test.stdout}\n${test.stderr}',
      );

      expect(readTemplateVersion(result.path), templateSchemaVersion);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'generate() từ chối ghi đè thư mục đã tồn tại và không rỗng',
    () async {
      final existing = Directory('${workDir.path}/taken');
      existing.createSync(recursive: true);
      File('${existing.path}/marker.txt').writeAsStringSync('do not touch');

      await expectLater(
        generate(name: 'taken', outputDir: workDir.path),
        throwsStateError,
      );
      // File gốc phải còn nguyên — generator không được đụng vào.
      expect(
        File('${existing.path}/marker.txt').readAsStringSync(),
        'do not touch',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
