import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runCheck(List<String> args) =>
    Process.run('dart', ['run', 'tool/asset_license_check.dart', ...args]);

void main() {
  group('CLI: dart run tool/asset_license_check.dart trên repo thật', () {
    test(
      '4 asset thật (audio/font/2 shader) đều có manifest hợp lệ: exit code 0',
      () async {
        final result = await _runCheck([]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout as String,
          contains('No asset license issues found.'),
        );
        expect(result.stdout as String, contains('4 asset runtime'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('CLI: fixture --root synthetic bắt lỗi thật', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'asset_license_check_test_',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<void> writeAsset(String relativePath, [String content = 'x']) async {
      final file = File('${tempDir.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    Future<void> writeManifest(Map<String, Object?> json) async {
      final file = File('${tempDir.path}/asset/LICENSES.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(json));
    }

    test(
      'asset không có entry manifest -> exit code 1, báo đúng path',
      () async {
        await writeAsset('asset/new_sound.ogg');
        await writeManifest({'schemaVersion': 1, 'entries': []});

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('missing'));
        expect(result.stdout as String, contains('asset/new_sound.ogg'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'license bị cấm phân phối -> exit code 1, báo đúng disallowedLicense',
      () async {
        await writeAsset('shaders/x.frag');
        await writeManifest({
          'schemaVersion': 1,
          'entries': [
            {
              'path': 'shaders/x.frag',
              'owner': 'someone',
              'license': 'proprietary',
              'source': 'unknown',
            },
          ],
        });

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('disallowedLicense'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'manifest có entry thừa (asset đã xoá) -> exit code 1, báo đúng stale',
      () async {
        await writeManifest({
          'schemaVersion': 1,
          'entries': [
            {
              'path': 'asset/deleted.png',
              'owner': 'a',
              'license': 'MIT',
              'source': 'b',
            },
          ],
        });

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('stale'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'asset + manifest khớp nhau hoàn toàn -> exit code 0 trên fixture riêng',
      () async {
        await writeAsset('asset/ok.ogg');
        await writeManifest({
          'schemaVersion': 1,
          'entries': [
            {
              'path': 'asset/ok.ogg',
              'owner': 'a',
              'license': 'MIT',
              'source': 'original work',
            },
          ],
        });

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'không có file manifest nào -> vẫn không crash, báo missing cho mọi asset',
      () async {
        await writeAsset('asset/no_manifest.ogg');

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('missing'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      '.DS_Store và LICENSES.json tự thân không bị coi là asset cần khai',
      () async {
        await writeAsset('asset/.DS_Store', 'junk');
        await writeManifest({'schemaVersion': 1, 'entries': []});

        final result = await _runCheck(['--root=${tempDir.path}']);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout as String, contains('0 asset runtime'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
