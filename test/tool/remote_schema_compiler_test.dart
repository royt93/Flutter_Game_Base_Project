import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';

Future<ProcessResult> _run(List<String> args) =>
    Process.run('dart', ['run', 'tool/remote_schema_compiler.dart', ...args]);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('remote_schema_compiler_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CLI: schema hợp lệ -> sinh đúng file, code chạy được thật', () {
    test('sinh model, dart run harness import trực tiếp cho ra kết quả đúng', () async {
      final schemaPath = '${tempDir.path}/schema.json';
      File(schemaPath).writeAsStringSync(
        jsonEncode({
          'packName': 'shopCatalog',
          'versions': [
            {
              'version': 1,
              'fields': [
                {'name': 'title', 'type': 'string'},
                {'name': 'price', 'type': 'int'},
              ],
            },
          ],
        }),
      );
      final outDir = '${tempDir.path}/out';

      final result = await _run(['--schema=$schemaPath', '--outDir=$outDir']);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final generatedPath = '$outDir/shop_catalog_content.g.dart';
      expect(File(generatedPath).existsSync(), isTrue);
      final generatedSource = File(generatedPath).readAsStringSync();
      expect(generatedSource, isNot(contains('import ')));

      // Bằng chứng THẬT code sinh ra compile và chạy được, không chỉ khớp
      // string mẫu — viết 1 harness import trực tiếp file .g.dart vừa sinh
      // (relative import, không cần package context) rồi `dart run` nó.
      File('$outDir/harness.dart').writeAsStringSync('''
import 'dart:convert';
import 'shop_catalog_content.g.dart';

void main() {
  final json = jsonDecode(
    '{"title":"Sword","price":100}',
  ) as Map<String, Object?>;
  final a = ShopCatalogContent.fromJson(json);
  final b = ShopCatalogContent(title: 'Sword', price: 100);
  print(a == b);
  print(jsonEncode(a.toJson()));
}
''');
      final harnessResult = await Process.run('dart', [
        'run',
        'harness.dart',
      ], workingDirectory: outDir);

      expect(
        harnessResult.exitCode,
        0,
        reason: '${harnessResult.stdout}\n${harnessResult.stderr}',
      );
      final lines = (harnessResult.stdout as String).trim().split('\n');
      expect(lines[0], 'true');
      expect(jsonDecode(lines[1]), {'title': 'Sword', 'price': 100});
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('CLI: schema hỏng -> KHÔNG sinh code, exit 1', () {
    test('packName không phải identifier -> reject, không ghi file nào', () async {
      final schemaPath = '${tempDir.path}/schema.json';
      File(schemaPath).writeAsStringSync(
        jsonEncode({
          'packName': '1-bad',
          'versions': [
            {
              'version': 1,
              'fields': [
                {'name': 'x', 'type': 'string'},
              ],
            },
          ],
        }),
      );
      final outDir = '${tempDir.path}/out';

      final result = await _run(['--schema=$schemaPath', '--outDir=$outDir']);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Schema invalid'));
      expect(Directory(outDir).existsSync(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('CLI: --fixture/--secret gate signature/version trước khi sinh code', () {
    const secret = 'shared-secret';

    test('fixture ký sai secret -> reject, không sinh file', () async {
      final schemaPath = '${tempDir.path}/schema.json';
      File(schemaPath).writeAsStringSync(
        jsonEncode({
          'packName': 'pack',
          'versions': [
            {
              'version': 1,
              'fields': [
                {'name': 'x', 'type': 'string'},
              ],
            },
          ],
        }),
      );
      final fixturePath = '${tempDir.path}/fixture.json';
      final signed = signExport({'schemaVersion': 1, 'x': 'a'}, 'wrong-secret');
      File(fixturePath).writeAsStringSync(jsonEncode(signed));
      final outDir = '${tempDir.path}/out';

      final result = await _run([
        '--schema=$schemaPath',
        '--outDir=$outDir',
        '--fixture=$fixturePath',
        '--secret=$secret',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Fixture rejected'));
      expect(Directory(outDir).existsSync(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('fixture ký đúng, version hợp lệ -> verify OK rồi mới sinh code', () async {
      final schemaPath = '${tempDir.path}/schema.json';
      File(schemaPath).writeAsStringSync(
        jsonEncode({
          'packName': 'pack',
          'versions': [
            {
              'version': 1,
              'fields': [
                {'name': 'x', 'type': 'string'},
              ],
            },
          ],
        }),
      );
      final fixturePath = '${tempDir.path}/fixture.json';
      final signed = signExport({'schemaVersion': 1, 'x': 'a'}, secret);
      File(fixturePath).writeAsStringSync(jsonEncode(signed));
      final outDir = '${tempDir.path}/out';

      final result = await _run([
        '--schema=$schemaPath',
        '--outDir=$outDir',
        '--fixture=$fixturePath',
        '--secret=$secret',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Fixture verified OK'));
      expect(File('$outDir/pack_content.g.dart').existsSync(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
