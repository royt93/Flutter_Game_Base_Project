import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';
import 'package:roy_casual_kit/core/utils/remote_schema_compiler.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

RemoteSchemaVersion _v1() => const RemoteSchemaVersion(
  version: 1,
  fields: [
    RemoteSchemaField(name: 'title', type: RemoteSchemaFieldType.string),
  ],
);

RemoteSchemaVersion _v2() => const RemoteSchemaVersion(
  version: 2,
  fields: [
    RemoteSchemaField(name: 'title', type: RemoteSchemaFieldType.string),
    RemoteSchemaField(name: 'price', type: RemoteSchemaFieldType.int),
  ],
);

void main() {
  group('RemoteSchemaDef: validation là cổng an toàn duy nhất', () {
    test('packName không phải Dart identifier hợp lệ -> throw', () {
      expect(
        () => RemoteSchemaDef(packName: '1bad-name', versions: [_v1()]),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('versions rỗng -> throw', () {
      expect(
        () => RemoteSchemaDef(packName: 'pack', versions: const []),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('2 version trùng số -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [_v1(), const RemoteSchemaVersion(version: 1, fields: [
            RemoteSchemaField(name: 'x', type: RemoteSchemaFieldType.string),
          ])],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('version âm -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [
            const RemoteSchemaVersion(version: -1, fields: [
              RemoteSchemaField(name: 'x', type: RemoteSchemaFieldType.string),
            ]),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('1 version không có field nào -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: const [RemoteSchemaVersion(version: 1, fields: [])],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('2 field trùng tên trong cùng version -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [
            const RemoteSchemaVersion(version: 1, fields: [
              RemoteSchemaField(name: 'x', type: RemoteSchemaFieldType.string),
              RemoteSchemaField(name: 'x', type: RemoteSchemaFieldType.int),
            ]),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('field name không phải Dart identifier hợp lệ -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [
            const RemoteSchemaVersion(version: 1, fields: [
              RemoteSchemaField(name: '2x', type: RemoteSchemaFieldType.string),
            ]),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('schema hợp lệ: versions tự sắp xếp tăng dần, current là version lớn nhất', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v2(), _v1()]);

      expect(schema.versions.map((v) => v.version), [1, 2]);
      expect(schema.current.version, 2);
    });
  });

  group('generateModelSource: sinh Dart hợp lệ, không import gì', () {
    test('output chứa đúng class name, field, fromJson/toJson', () {
      final schema = RemoteSchemaDef(packName: 'shopCatalog', versions: [_v2()]);
      final source = generateModelSource(schema);

      expect(source, contains('class ShopCatalogContent {'));
      expect(source, contains('final String title;'));
      expect(source, contains('final int price;'));
      expect(source, contains('factory ShopCatalogContent.fromJson'));
      expect(source, contains('Map<String, Object?> toJson()'));
      expect(source, isNot(contains('import ')));
    });

    test('chỉ sinh helper reader cho type thực sự dùng', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]); // chỉ có string
      final source = generateModelSource(schema);

      expect(source, contains('_asString'));
      expect(source, isNot(contains('_asInt')));
      expect(source, isNot(contains('_asBool')));
      expect(source, isNot(contains('_asDouble')));
    });
  });

  group('buildMigrationRegistry: ghép đúng SaveMigrationRegistry có sẵn (FEAT-37)', () {
    test('thiếu migrate function cho 1 hop -> throw RemoteSchemaCompilerException', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1(), _v2()]);

      expect(
        () => buildMigrationRegistry(schema, stepMigrations: const {}),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('happy path: migrate v1 -> v2 áp dụng đúng qua registry đã ghép', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1(), _v2()]);
      final registry = buildMigrationRegistry(
        schema,
        stepMigrations: {
          1: (json) => {...json, 'price': 0},
        },
      );

      final migrated = registry.migrate(1, {'title': 'Sword'});

      expect(migrated, {'title': 'Sword', 'price': 0});
      expect(registry.currentVersion, 2);
    });

    test('chain 3 version, thiếu 1 trong 2 hop -> vẫn bắt được (không chỉ check hop đầu)', () {
      final v3 = const RemoteSchemaVersion(version: 3, fields: [
        RemoteSchemaField(name: 'title', type: RemoteSchemaFieldType.string),
        RemoteSchemaField(name: 'price', type: RemoteSchemaFieldType.int),
        RemoteSchemaField(name: 'qty', type: RemoteSchemaFieldType.int),
      ]);
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1(), _v2(), v3]);

      expect(
        () => buildMigrationRegistry(
          schema,
          stepMigrations: {1: (json) => {...json, 'price': 0}},
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });
  });

  group('verifySignedFixture: cùng gate signature/version RemoteContentPack dùng lúc runtime', () {
    const secret = 'test-secret';

    test('fixture ký đúng, version hợp lệ -> SdkSuccess', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
      final signed = signExport({'schemaVersion': 1, 'title': 'Sword'}, secret);

      final result = verifySignedFixture(schema, signed, secret);

      expect(result, isA<SdkSuccess<Map<String, Object?>>>());
      expect(result.value!['title'], 'Sword');
    });

    test('sai secret -> SdkFailure, không throw', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
      final signed = signExport({'schemaVersion': 1, 'title': 'Sword'}, secret);

      final result = verifySignedFixture(schema, signed, 'wrong-secret');

      expect(result, isA<SdkFailure<Map<String, Object?>>>());
    });

    test('thiếu checksum (không phải fixture đã ký) -> SdkFailure', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);

      final result = verifySignedFixture(schema, {'schemaVersion': 1, 'title': 'x'}, secret);

      expect(result, isA<SdkFailure<Map<String, Object?>>>());
    });

    test('schemaVersion mới hơn schema đã compile -> SdkFailure (không bao giờ chấp nhận version tương lai)', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
      final signed = signExport({'schemaVersion': 99, 'title': 'Sword'}, secret);

      final result = verifySignedFixture(schema, signed, secret);

      expect(result, isA<SdkFailure<Map<String, Object?>>>());
      expect((result as SdkFailure).message, contains('newer'));
    });

    test('tamper dữ liệu sau khi ký -> checksum sai, SdkFailure', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
      final signed = signExport({'schemaVersion': 1, 'title': 'Sword'}, secret);
      final tampered = {...signed, 'title': 'Hacked'};

      final result = verifySignedFixture(schema, tampered, secret);

      expect(result, isA<SdkFailure<Map<String, Object?>>>());
    });
  });
}
