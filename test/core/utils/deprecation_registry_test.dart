import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/deprecation_registry.dart';

void main() {
  group('DeprecatedApi validation', () {
    test('semver hợp lệ (x.y.z) tạo được bình thường', () {
      expect(
        () => DeprecatedApi(
          name: 'Foo.bar',
          deprecatedInVersion: '0.2.0',
          removeInVersion: '0.4.0',
          migrationHint: 'Use Foo.baz instead.',
        ),
        returnsNormally,
      );
    });

    test('semver sai định dạng throw ArgumentError ngay lúc construct', () {
      expect(
        () => DeprecatedApi(
          name: 'Foo.bar',
          deprecatedInVersion: 'v0.2',
          removeInVersion: '0.4.0',
          migrationHint: 'x',
        ),
        throwsArgumentError,
      );
    });

    test('removeInVersion <= deprecatedInVersion throw (grace period vô nghĩa)', () {
      expect(
        () => DeprecatedApi(
          name: 'Foo.bar',
          deprecatedInVersion: '0.4.0',
          removeInVersion: '0.2.0',
          migrationHint: 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('DeprecationRegistry.checkAll', () {
    final registry = DeprecationRegistry([
      DeprecatedApi(
        name: 'Foo.oldMethod',
        deprecatedInVersion: '0.2.0',
        removeInVersion: '0.4.0',
        migrationHint: 'Use Foo.newMethod instead.',
      ),
      DeprecatedApi(
        name: 'Bar.legacyField',
        deprecatedInVersion: '0.1.0',
        removeInVersion: '0.3.0',
        migrationHint: 'Use Bar.field instead.',
      ),
    ]);

    test('currentVersion còn trong grace period: status active', () {
      final results = registry.checkAll('0.2.5');

      expect(results.every((r) => r.status == DeprecationStatus.active), isTrue);
    });

    test('currentVersion == removeInVersion: pastGrace (biên inclusive)', () {
      final results = registry.checkAll('0.3.0');
      final barResult = results.firstWhere((r) => r.api.name == 'Bar.legacyField');

      expect(barResult.status, DeprecationStatus.pastGrace);
    });

    test('currentVersion vượt xa removeInVersion: pastGrace', () {
      final results = registry.checkAll('1.0.0');

      expect(results.every((r) => r.status == DeprecationStatus.pastGrace), isTrue);
    });

    test('mỗi entry được đánh giá độc lập theo removeInVersion riêng', () {
      final results = registry.checkAll('0.3.5');
      final foo = results.firstWhere((r) => r.api.name == 'Foo.oldMethod');
      final bar = results.firstWhere((r) => r.api.name == 'Bar.legacyField');

      expect(foo.status, DeprecationStatus.active); // removeInVersion 0.4.0 chưa tới
      expect(bar.status, DeprecationStatus.pastGrace); // removeInVersion 0.3.0 đã qua
    });

    test('pastGraceOnly() chỉ trả về entry đã quá hạn', () {
      final pastGrace = registry.pastGraceOnly('0.3.5');

      expect(pastGrace, hasLength(1));
      expect(pastGrace.single.api.name, 'Bar.legacyField');
    });

    test('currentVersion sai định dạng throw ArgumentError', () {
      expect(() => registry.checkAll('not-a-version'), throwsArgumentError);
    });

    test('registry rỗng: checkAll trả danh sách rỗng, không throw', () {
      final empty = DeprecationRegistry([]);
      expect(empty.checkAll('1.0.0'), isEmpty);
    });
  });
}
