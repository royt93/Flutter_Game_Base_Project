import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runCheck(List<String> args) => Process.run(
  'dart',
  ['run', 'tool/dependency_sbom_check.dart', ...args],
);

void main() {
  group('CLI: dart run tool/dependency_sbom_check.dart trên repo thật', () {
    test(
      'chạy được, in đúng số package, exit code phản ánh đúng finding thật (dbus/MPL-2.0)',
      () async {
        final result = await _runCheck([]);
        expect(result.stdout as String, contains('package'));
        // Repo thật hiện có đúng 1 finding low-severity thật (dbus dùng
        // MPL-2.0 — không permissive, không GPL-family, cần review pháp
        // lý của maintainer) — verify hành vi thật, không giả vờ sạch.
        expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
        expect(result.stdout as String, contains('dbus'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('--minSeverity=medium bỏ qua finding low (dbus), exit code 0', () async {
      final result = await _runCheck(['--minSeverity=medium']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('CLI: fixture synthetic bắt lỗi thật', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dependency_sbom_check_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    void writeFile(String relativePath, String content) {
      final file = File('${tempDir.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    const fakeLock = '''
packages:
  fake_pkg:
    dependency: transitive
    description:
      name: fake_pkg
      sha256: "abc"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
''';
    const fakePubspec = '''
name: fixture_app
version: 1.0.0
dependencies:
  fake_pkg: ^1.0.0
  wild_pkg:
''';

    test('package không có LICENSE trong pubCache giả -> unknownLicense, exit 1', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', fakePubspec);
      final emptyPubCache = Directory('${tempDir.path}/empty_pub_cache')..createSync();

      final result = await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${emptyPubCache.path}',
      ]);

      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout as String, contains('unknownLicense'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('dependency không pin version (wild_pkg:) -> unpinnedConstraint bị bắt', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', fakePubspec);
      final emptyPubCache = Directory('${tempDir.path}/empty_pub_cache')..createSync();

      final result = await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${emptyPubCache.path}',
      ]);

      expect(result.stdout as String, contains('unpinnedConstraint'));
      expect(result.stdout as String, contains('wild_pkg'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('package có LICENSE MIT thật trong pubCache giả -> không báo unknownLicense', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', 'name: x\nversion: 1.0.0\ndependencies:\n  fake_pkg: ^1.0.0\n');
      writeFile(
        'fake_pub_cache/hosted/pub.dev/fake_pkg-1.0.0/LICENSE',
        'MIT License\n\nCopyright (c) 2024',
      );

      final result = await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${tempDir.path}/fake_pub_cache',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout as String, contains('No dependency issues found.'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('advisory khớp version đang dùng -> báo vulnerability, exit 1', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', 'name: x\nversion: 1.0.0\ndependencies:\n  fake_pkg: ^1.0.0\n');
      writeFile(
        'fake_pub_cache/hosted/pub.dev/fake_pkg-1.0.0/LICENSE',
        'MIT License\n\nCopyright (c) 2024',
      );
      writeFile(
        'advisories.json',
        jsonEncode([
          {
            'package': 'fake_pkg',
            'version': '1.0.0',
            'severity': 'critical',
            'description': 'lỗ hổng giả lập cho test',
          },
        ]),
      );

      final result = await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${tempDir.path}/fake_pub_cache',
        '--advisories=${tempDir.path}/advisories.json',
      ]);

      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('vulnerability'));
      expect(result.stdout as String, contains('critical'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('suppression có owner/reason/expiresAtMs còn hạn -> ẩn đúng finding', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', 'name: x\nversion: 1.0.0\ndependencies:\n  fake_pkg: ^1.0.0\n');
      final emptyPubCache = Directory('${tempDir.path}/empty_pub_cache')..createSync();
      writeFile(
        'suppressions.json',
        jsonEncode([
          {
            'package': 'fake_pkg',
            'kind': 'unknownLicense',
            'reason': 'đã review tay, an toàn cho mục đích nội bộ',
            'owner': 'test-owner',
            'expiresAtMs': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          },
        ]),
      );

      final result = await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${emptyPubCache.path}',
        '--suppressions=${tempDir.path}/suppressions.json',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('--out= ghi ra file SBOM JSON hợp lệ, đọc lại parse được', () async {
      writeFile('pubspec.lock', fakeLock);
      writeFile('pubspec.yaml', fakePubspec);
      final emptyPubCache = Directory('${tempDir.path}/empty_pub_cache')..createSync();

      await _runCheck([
        '--lockfile=${tempDir.path}/pubspec.lock',
        '--pubspec=${tempDir.path}/pubspec.yaml',
        '--pubCache=${emptyPubCache.path}',
        '--out=${tempDir.path}/sbom.json',
      ]);

      final sbomFile = File('${tempDir.path}/sbom.json');
      expect(sbomFile.existsSync(), isTrue);
      final decoded = jsonDecode(sbomFile.readAsStringSync()) as Map;
      expect(decoded['entries'], isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
