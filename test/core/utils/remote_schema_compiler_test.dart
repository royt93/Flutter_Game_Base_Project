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
          versions: [
            _v1(),
            const RemoteSchemaVersion(
              version: 1,
              fields: [
                RemoteSchemaField(
                  name: 'x',
                  type: RemoteSchemaFieldType.string,
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('version âm -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [
            const RemoteSchemaVersion(
              version: -1,
              fields: [
                RemoteSchemaField(
                  name: 'x',
                  type: RemoteSchemaFieldType.string,
                ),
              ],
            ),
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
            const RemoteSchemaVersion(
              version: 1,
              fields: [
                RemoteSchemaField(
                  name: 'x',
                  type: RemoteSchemaFieldType.string,
                ),
                RemoteSchemaField(name: 'x', type: RemoteSchemaFieldType.int),
              ],
            ),
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
            const RemoteSchemaVersion(
              version: 1,
              fields: [
                RemoteSchemaField(
                  name: '2x',
                  type: RemoteSchemaFieldType.string,
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('BUG-97: packName là Dart reserved keyword ("class") -> throw '
        '(regex identifier cũ chấp nhận, codegen sinh ra "class ClassContent" '
        'không compile được)', () {
      expect(
        () => RemoteSchemaDef(packName: 'class', versions: [_v1()]),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test('BUG-97: field name là Dart reserved keyword ("final") -> throw', () {
      expect(
        () => RemoteSchemaDef(
          packName: 'pack',
          versions: [
            const RemoteSchemaVersion(
              version: 1,
              fields: [
                RemoteSchemaField(
                  name: 'final',
                  type: RemoteSchemaFieldType.string,
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<RemoteSchemaCompilerException>()),
      );
    });

    test(
      'BUG-97: built-in identifier ("dynamic") không phải reserved word thật '
      '-> vẫn được chấp nhận (chỉ chặn reserved words, không chặn mọi '
      'built-in type name)',
      () {
        expect(
          () => RemoteSchemaDef(packName: 'dynamic', versions: [_v1()]),
          returnsNormally,
        );
      },
    );

    test(
      'BUG-97 audit fix: "await"/"yield" là contextual keyword, chỉ reserved '
      'BÊN TRONG thân hàm async/generator — hợp lệ làm tên class/field ở '
      'mọi nơi khác (generated model code luôn sync) -> phải được chấp nhận',
      () {
        expect(
          () => RemoteSchemaDef(packName: 'await', versions: [_v1()]),
          returnsNormally,
        );
        expect(
          () => RemoteSchemaDef(
            packName: 'pack',
            versions: [
              const RemoteSchemaVersion(
                version: 1,
                fields: [
                  RemoteSchemaField(
                    name: 'yield',
                    type: RemoteSchemaFieldType.string,
                  ),
                ],
              ),
            ],
          ),
          returnsNormally,
        );
      },
    );

    test(
      'schema hợp lệ: versions tự sắp xếp tăng dần, current là version lớn nhất',
      () {
        final schema = RemoteSchemaDef(
          packName: 'pack',
          versions: [_v2(), _v1()],
        );

        expect(schema.versions.map((v) => v.version), [1, 2]);
        expect(schema.current.version, 2);
      },
    );

    test('BUG-97: mutate list fields GỐC (growable, không phải const) SAU khi '
        'validate -> schema đã tạo KHÔNG đổi (deep-freeze/clone tại validate, '
        'không giữ reference sống tới list của caller)', () {
      final mutableFields = <RemoteSchemaField>[
        const RemoteSchemaField(
          name: 'title',
          type: RemoteSchemaFieldType.string,
        ),
      ];
      final version = RemoteSchemaVersion(version: 1, fields: mutableFields);
      final schema = RemoteSchemaDef(packName: 'pack', versions: [version]);

      mutableFields.add(
        const RemoteSchemaField(
          name: 'sneaky',
          type: RemoteSchemaFieldType.int,
        ),
      );

      expect(schema.current.fields, hasLength(1));
      expect(schema.current.fields.single.name, 'title');
    });

    test('BUG-97: schema.current.fields là unmodifiable -> mutate trực tiếp '
        'qua schema throw thay vì âm thầm đổi schema đã verify', () {
      final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);

      expect(
        () => schema.current.fields.add(
          const RemoteSchemaField(
            name: 'sneaky',
            type: RemoteSchemaFieldType.int,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('generateModelSource: sinh Dart hợp lệ, không import gì', () {
    test('output chứa đúng class name, field, fromJson/toJson', () {
      final schema = RemoteSchemaDef(
        packName: 'shopCatalog',
        versions: [_v2()],
      );
      final source = generateModelSource(schema);

      expect(source, contains('class ShopCatalogContent {'));
      expect(source, contains('final String title;'));
      expect(source, contains('final int price;'));
      expect(source, contains('factory ShopCatalogContent.fromJson'));
      expect(source, contains('Map<String, Object?> toJson()'));
      expect(source, isNot(contains('import ')));
    });

    test('field double và bool: đúng kiểu Dart, đúng reader, chỉ thêm helper đã dùng', () {
      final schema = RemoteSchemaDef(
        packName: 'pack',
        versions: const [
          RemoteSchemaVersion(
            version: 1,
            fields: [
              RemoteSchemaField(name: 'ratio', type: RemoteSchemaFieldType.double),
              RemoteSchemaField(name: 'enabled', type: RemoteSchemaFieldType.boolean),
            ],
          ),
        ],
      );
      final source = generateModelSource(schema);

      expect(source, contains('final double ratio;'));
      expect(source, contains('final bool enabled;'));
      expect(source, contains('_asDouble(json[\'ratio\'])'));
      expect(source, contains('_asBool(json[\'enabled\'])'));
      expect(source, contains('double _asDouble('));
      expect(source, contains('bool _asBool('));
      expect(source, isNot(contains('_asString')));
      expect(source, isNot(contains('_asInt')));
    });

    test('RemoteSchemaCompilerException.toString mang theo message', () {
      expect(
        const RemoteSchemaCompilerException('boom').toString(),
        'RemoteSchemaCompilerException: boom',
      );
    });

    test('chỉ sinh helper reader cho type thực sự dùng', () {
      final schema = RemoteSchemaDef(
        packName: 'pack',
        versions: [_v1()],
      ); // chỉ có string
      final source = generateModelSource(schema);

      expect(source, contains('_asString'));
      expect(source, isNot(contains('_asInt')));
      expect(source, isNot(contains('_asBool')));
      expect(source, isNot(contains('_asDouble')));
    });
  });

  group(
    'buildMigrationRegistry: ghép đúng SaveMigrationRegistry có sẵn (FEAT-37)',
    () {
      test(
        'thiếu migrate function cho 1 hop -> throw RemoteSchemaCompilerException',
        () {
          final schema = RemoteSchemaDef(
            packName: 'pack',
            versions: [_v1(), _v2()],
          );

          expect(
            () => buildMigrationRegistry(schema, stepMigrations: const {}),
            throwsA(isA<RemoteSchemaCompilerException>()),
          );
        },
      );

      test(
        'happy path: migrate v1 -> v2 áp dụng đúng qua registry đã ghép',
        () {
          final schema = RemoteSchemaDef(
            packName: 'pack',
            versions: [_v1(), _v2()],
          );
          final registry = buildMigrationRegistry(
            schema,
            stepMigrations: {
              1: (json) => {...json, 'price': 0},
            },
          );

          final migrated = registry.migrate(1, {'title': 'Sword'});

          expect(migrated, {'title': 'Sword', 'price': 0});
          expect(registry.currentVersion, 2);
        },
      );

      test(
        'chain 3 version, thiếu 1 trong 2 hop -> vẫn bắt được (không chỉ check hop đầu)',
        () {
          final v3 = const RemoteSchemaVersion(
            version: 3,
            fields: [
              RemoteSchemaField(
                name: 'title',
                type: RemoteSchemaFieldType.string,
              ),
              RemoteSchemaField(name: 'price', type: RemoteSchemaFieldType.int),
              RemoteSchemaField(name: 'qty', type: RemoteSchemaFieldType.int),
            ],
          );
          final schema = RemoteSchemaDef(
            packName: 'pack',
            versions: [_v1(), _v2(), v3],
          );

          expect(
            () => buildMigrationRegistry(
              schema,
              stepMigrations: {
                1: (json) => {...json, 'price': 0},
              },
            ),
            throwsA(isA<RemoteSchemaCompilerException>()),
          );
        },
      );
    },
  );

  group(
    'verifySignedFixture: cùng gate signature/version RemoteContentPack dùng lúc runtime',
    () {
      const secret = 'test-secret';

      test('fixture ký đúng, version hợp lệ -> SdkSuccess', () {
        final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
        final signed = signExport({
          'schemaVersion': 1,
          'title': 'Sword',
        }, secret);

        final result = verifySignedFixture(schema, signed, secret);

        expect(result, isA<SdkSuccess<Map<String, Object?>>>());
        expect(result.value!['title'], 'Sword');
      });

      test('sai secret -> SdkFailure, không throw', () {
        final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
        final signed = signExport({
          'schemaVersion': 1,
          'title': 'Sword',
        }, secret);

        final result = verifySignedFixture(schema, signed, 'wrong-secret');

        expect(result, isA<SdkFailure<Map<String, Object?>>>());
      });

      test('thiếu checksum (không phải fixture đã ký) -> SdkFailure', () {
        final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);

        final result = verifySignedFixture(schema, {
          'schemaVersion': 1,
          'title': 'x',
        }, secret);

        expect(result, isA<SdkFailure<Map<String, Object?>>>());
      });

      test(
        'schemaVersion mới hơn schema đã compile -> SdkFailure (không bao giờ chấp nhận version tương lai)',
        () {
          final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
          final signed = signExport({
            'schemaVersion': 99,
            'title': 'Sword',
          }, secret);

          final result = verifySignedFixture(schema, signed, secret);

          expect(result, isA<SdkFailure<Map<String, Object?>>>());
          expect((result as SdkFailure).message, contains('newer'));
        },
      );

      test('tamper dữ liệu sau khi ký -> checksum sai, SdkFailure', () {
        final schema = RemoteSchemaDef(packName: 'pack', versions: [_v1()]);
        final signed = signExport({
          'schemaVersion': 1,
          'title': 'Sword',
        }, secret);
        final tampered = {...signed, 'title': 'Hacked'};

        final result = verifySignedFixture(schema, tampered, secret);

        expect(result, isA<SdkFailure<Map<String, Object?>>>());
      });
    },
  );
}
