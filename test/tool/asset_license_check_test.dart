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

  group('BUG-99: example/assets dùng --asset-roots=assets', () {
    test(
      'fixture mp3 trong assets/ không có manifest entry -> exit 1, báo đúng path',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'asset_license_example_missing_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final audio = File('${tempDir.path}/assets/audio/missing.mp3');
        audio.parent.createSync(recursive: true);
        audio.writeAsStringSync('x');
        final manifest = File('${tempDir.path}/assets/LICENSES.json');
        manifest.writeAsStringSync(
          jsonEncode({'schemaVersion': 1, 'entries': []}),
        );

        final result = await _runCheck([
          '--root=${tempDir.path}',
          '--asset-roots=assets',
          '--manifest=assets/LICENSES.json',
        ]);

        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('missing'));
        expect(result.stdout as String, contains('assets/audio/missing.mp3'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'repo thật: example/assets có 6 runtime assets + manifest hợp lệ -> pass',
      () async {
        final result = await _runCheck([
          '--root=example',
          '--asset-roots=assets',
          '--manifest=assets/LICENSES.json',
        ]);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout as String, contains('6 asset runtime'));
        expect(
          result.stdout as String,
          contains('No asset license issues found.'),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('audit fix: --asset-roots trùng lặp (assets,assets) được dedupe, '
        'không double-count 6 asset thật thành 12', () async {
      final result = await _runCheck([
        '--root=example',
        '--asset-roots=assets, assets',
        '--manifest=assets/LICENSES.json',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout as String, contains('6 asset runtime'));
      expect(result.stdout as String, isNot(contains('12 asset runtime')));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test(
      'fixture assets/ có manifest hợp lệ -> pass',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'asset_license_example_valid_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final audio = File('${tempDir.path}/assets/audio/ok.mp3');
        audio.parent.createSync(recursive: true);
        audio.writeAsStringSync('x');
        File('${tempDir.path}/assets/LICENSES.json').writeAsStringSync(
          jsonEncode({
            'schemaVersion': 1,
            'entries': [
              {
                'path': 'assets/audio/ok.mp3',
                'owner': 'test',
                'license': 'MIT',
                'source': 'fixture',
              },
            ],
          }),
        );

        final result = await _runCheck([
          '--root=${tempDir.path}',
          '--asset-roots=assets',
          '--manifest=assets/LICENSES.json',
        ]);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout as String, contains('1 asset runtime'));
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
      '.DS_Store, LICENSES.json và LICENSES.md tự thân không bị coi là asset cần khai',
      () async {
        await writeAsset('asset/.DS_Store', 'junk');
        await writeAsset('asset/LICENSES.md', '# attribution');
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
