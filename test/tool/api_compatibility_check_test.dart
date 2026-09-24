import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runCheck(List<String> args) =>
    Process.run('dart', ['run', 'tool/api_compatibility.dart', ...args]);

void main() {
  group('CLI: dart run tool/api_compatibility.dart trên repo thật', () {
    test(
      'repo thật, chưa đổi export nào: exit code 0, unchanged',
      () async {
        final result = await _runCheck(['check']);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('API compatibility: unchanged'),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('CLI: fixture --root synthetic bắt đúng 3 loại thay đổi export', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'api_compatibility_check_test_',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<void> writeFile(String relativePath, String content) async {
      final file = File('${tempDir.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    Future<void> writeSnapshot(Map<String, Object?> json) =>
        writeFile('tool/api_snapshot.json', jsonEncode(json));

    // Ghi 2 mục vào CHANGELOG (mục hiện tại + 1 mục cũ hơn bên dưới), KHÔNG
    // chỉ 1 mục — `_currentChangelogSection`'s regex tìm ranh giới mục hiện
    // tại qua lookahead `(?=^## |\Z)`, và `\Z` không phải escape hợp lệ
    // trong RegExp của Dart (ECMAScript syntax, không giống Perl/ICU) nên
    // KHÔNG BAO GIỜ khớp cuối chuỗi thật — với CHANGELOG chỉ có đúng 1 mục,
    // section luôn trả về rỗng bất kể nội dung thật là gì. Đây là 1 bug có
    // thật, đã verify độc lập (script tái hiện riêng), nhưng KHÔNG sửa ở
    // đây — nằm ngoài phạm vi ENH-92 (viết test, không phải sửa gate logic)
    // và repo thật không bao giờ trúng nhánh này vì CHANGELOG.md thật luôn
    // có nhiều mục. Xem BUG-74 cho việc sửa gốc rễ.
    Future<void> writeChangelog(String currentVersion, String body) =>
        writeFile(
          'CHANGELOG.md',
          '## $currentVersion\n$body\n\n## 0.0.1\n- initial\n',
        );

    Future<void> writePubspec(String version) =>
        writeFile('pubspec.yaml', 'name: fixture\nversion: $version\n');

    Future<void> writeEntrypoint(List<String> exportedFiles) => writeFile(
      'lib/roy_casual_kit.dart',
      exportedFiles.map((f) => "export '$f';").join('\n'),
    );

    test(
      'export mới thêm (additive), changelog có mục cho version hiện tại: '
      'exit code 0, "additive", Added đúng symbol mới',
      () async {
        await writeEntrypoint(['foo.dart', 'bar.dart']);
        await writeFile('lib/foo.dart', 'class Foo {}');
        await writeFile('lib/bar.dart', 'class Bar {}');
        await writeSnapshot({
          'entrypoint': 'lib/roy_casual_kit.dart',
          'exports': ['foo.dart'],
          'symbols': ['foo.dart:Foo'],
        });
        await writePubspec('0.1.0');
        await writeChangelog('0.1.0', '- Added Bar.');

        final result = await _runCheck(['check', '--root=${tempDir.path}']);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('API compatibility: additive'),
        );
        expect(result.stdout as String, contains('bar.dart:Bar'));
        expect(result.stdout as String, contains('Removed: {}'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'export bị xoá (removed) + changelog KHÔNG có ghi chú BREAKING cho '
      'version hiện tại (không phải major): exit code khác 0, từ chối',
      () async {
        await writeEntrypoint(['foo.dart']);
        await writeFile('lib/foo.dart', 'class Foo {}');
        await writeSnapshot({
          'entrypoint': 'lib/roy_casual_kit.dart',
          'exports': ['foo.dart', 'bar.dart'],
          'symbols': ['foo.dart:Foo', 'bar.dart:Bar'],
        });
        await writePubspec('0.1.0');
        await writeChangelog('0.1.0', '- không nhắc gì tới việc xoá Bar');

        final result = await _runCheck(['check', '--root=${tempDir.path}']);

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr as String,
          contains('Breaking API removals require a major version'),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'export bị xoá (removed) + changelog CÓ ghi chú BREAKING cho version '
      'hiện tại: exit code 0, "breaking", Removed đúng symbol đã xoá',
      () async {
        await writeEntrypoint(['foo.dart']);
        await writeFile('lib/foo.dart', 'class Foo {}');
        await writeSnapshot({
          'entrypoint': 'lib/roy_casual_kit.dart',
          'exports': ['foo.dart', 'bar.dart'],
          'symbols': ['foo.dart:Foo', 'bar.dart:Bar'],
        });
        await writePubspec('0.1.0');
        await writeChangelog('0.1.0', '### BREAKING\n- Removed Bar.');

        final result = await _runCheck(['check', '--root=${tempDir.path}']);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('API compatibility: breaking'),
        );
        expect(result.stdout as String, contains('bar.dart:Bar'));
        expect(result.stdout as String, contains('Added: {}'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'không đổi gì (unchanged) trên fixture: exit code 0, "unchanged"',
      () async {
        await writeEntrypoint(['foo.dart']);
        await writeFile('lib/foo.dart', 'class Foo {}');
        await writeSnapshot({
          'entrypoint': 'lib/roy_casual_kit.dart',
          'exports': ['foo.dart'],
          'symbols': ['foo.dart:Foo'],
        });
        await writePubspec('0.1.0');
        await writeChangelog('0.1.0', '- không liên quan');

        final result = await _runCheck(['check', '--root=${tempDir.path}']);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('API compatibility: unchanged'),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'snapshot command với --root: ghi đúng file tool/api_snapshot.json '
      'vào fixture, KHÔNG đụng snapshot thật của repo',
      () async {
        await writeEntrypoint(['foo.dart']);
        await writeFile('lib/foo.dart', 'class Foo {}');
        // Tool ghi trực tiếp vào '$root/tool/api_snapshot.json' — không tự
        // tạo thư mục cha nếu chưa tồn tại (repo thật luôn có sẵn tool/,
        // nên trước giờ chưa lộ ra), fixture rỗng cần tự tạo trước.
        Directory('${tempDir.path}/tool').createSync(recursive: true);

        final result = await _runCheck([
          'snapshot',
          '--root=${tempDir.path}',
        ]);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final written = File(
          '${tempDir.path}/tool/api_snapshot.json',
        ).readAsStringSync();
        expect(written, contains('foo.dart:Foo'));

        // Repo thật không hề bị đụng tới.
        final realSnapshot = File('tool/api_snapshot.json').readAsStringSync();
        expect(realSnapshot, isNot(contains('lib/foo.dart')));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
