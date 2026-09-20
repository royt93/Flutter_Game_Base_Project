import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/asset_license_manifest.dart';

void main() {
  const goodEntry = AssetLicenseEntry(
    path: 'asset/audio/bkg.ogg',
    owner: 'royt93',
    license: 'MIT',
    source: 'original work',
  );

  group('AssetLicenseEntry: JSON round-trip', () {
    test('toJson/fromJson khớp đúng mọi field', () {
      final json = goodEntry.toJson();
      final parsed = AssetLicenseEntry.fromJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.path, goodEntry.path);
      expect(parsed.owner, goodEntry.owner);
      expect(parsed.license, goodEntry.license);
      expect(parsed.source, goodEntry.source);
      expect(parsed.attributionRequired, isFalse);
      expect(parsed.distributable, isTrue);
    });

    test('thiếu field bắt buộc -> null, không throw', () {
      expect(AssetLicenseEntry.fromJson({'path': 'a'}), isNull);
      expect(AssetLicenseEntry.fromJson({}), isNull);
    });

    test('distributable/attributionRequired mặc định đúng khi JSON không có field đó', () {
      final parsed = AssetLicenseEntry.fromJson({
        'path': 'a',
        'owner': 'b',
        'license': 'c',
        'source': 'd',
      });
      expect(parsed!.attributionRequired, isFalse);
      expect(parsed.distributable, isTrue);
    });
  });

  group('AssetLicenseManifest: JSON round-trip', () {
    test('manifest rỗng/rác -> entries rỗng, không throw', () {
      expect(AssetLicenseManifest.fromJson({}).entries, isEmpty);
      expect(AssetLicenseManifest.fromJson({'entries': 'not a list'}).entries, isEmpty);
      expect(AssetLicenseManifest.fromJson({'entries': [1, 2, 3]}).entries, isEmpty);
    });

    test('1 entry rác lẫn trong list không làm hỏng các entry tốt khác', () {
      final manifest = AssetLicenseManifest.fromJson({
        'entries': [goodEntry.toJson(), 'garbage', 42, null],
      });
      expect(manifest.entries, hasLength(1));
      expect(manifest.entries.single.path, goodEntry.path);
    });
  });

  group('validateAssetLicenses: missing/stale', () {
    test('asset runtime không có entry -> issue kind=missing', () {
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/audio/bkg.ogg'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: []),
      );
      expect(issues, hasLength(1));
      expect(issues.single.kind, AssetLicenseIssueKind.missing);
      expect(issues.single.path, 'asset/audio/bkg.ogg');
    });

    test('entry có nhưng asset đã xoá -> issue kind=stale', () {
      final issues = validateAssetLicenses(
        assetPaths: const [],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [goodEntry]),
      );
      expect(issues, hasLength(1));
      expect(issues.single.kind, AssetLicenseIssueKind.stale);
    });

    test('asset + entry khớp nhau hoàn toàn -> sạch, không issue', () {
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/audio/bkg.ogg'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [goodEntry]),
      );
      expect(issues, isEmpty);
    });
  });

  group('validateAssetLicenses: incomplete', () {
    test('owner/license/source rỗng -> issue kind=incomplete', () {
      const incomplete = AssetLicenseEntry(
        path: 'asset/x.png',
        owner: '',
        license: 'MIT',
        source: 'a',
      );
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/x.png'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [incomplete]),
      );
      expect(issues.any((i) => i.kind == AssetLicenseIssueKind.incomplete), isTrue);
    });
  });

  group('validateAssetLicenses: license denylist mặc định', () {
    for (final bad in defaultDisallowedLicenses) {
      test('license "$bad" trong denylist -> issue kind=disallowedLicense', () {
        final entry = AssetLicenseEntry(
          path: 'asset/x.png',
          owner: 'a',
          license: bad,
          source: 'b',
        );
        final issues = validateAssetLicenses(
          assetPaths: const ['asset/x.png'],
          manifest: AssetLicenseManifest(schemaVersion: 1, entries: [entry]),
        );
        expect(
          issues.any((i) => i.kind == AssetLicenseIssueKind.disallowedLicense),
          isTrue,
          reason: 'license "$bad" phải bị chặn',
        );
      });
    }

    test('license không nằm trong denylist -> không bị chặn vì lý do license', () {
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/audio/bkg.ogg'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [goodEntry]),
      );
      expect(issues.where((i) => i.kind == AssetLicenseIssueKind.disallowedLicense), isEmpty);
    });

    test('distributable: false -> bị chặn dù license hợp lệ', () {
      const notDistributable = AssetLicenseEntry(
        path: 'asset/x.png',
        owner: 'a',
        license: 'MIT',
        source: 'b',
        distributable: false,
      );
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/x.png'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [notDistributable]),
      );
      expect(issues.single.kind, AssetLicenseIssueKind.disallowedLicense);
    });

    test('denylist tuỳ biến được qua tham số disallowedLicenses', () {
      const entry = AssetLicenseEntry(
        path: 'asset/x.png',
        owner: 'a',
        license: 'weird-custom-license',
        source: 'b',
      );
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/x.png'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [entry]),
        disallowedLicenses: const {'weird-custom-license'},
      );
      expect(issues.single.kind, AssetLicenseIssueKind.disallowedLicense);
    });
  });

  group('validateAssetLicenses: nhiều issue cùng lúc trên 1 entry', () {
    test('1 entry vừa incomplete vừa disallowed -> báo cả 2 issue, không chỉ 1', () {
      const bad = AssetLicenseEntry(
        path: 'asset/x.png',
        owner: '',
        license: 'unknown',
        source: 'a',
      );
      final issues = validateAssetLicenses(
        assetPaths: const ['asset/x.png'],
        manifest: const AssetLicenseManifest(schemaVersion: 1, entries: [bad]),
      );
      expect(issues.map((i) => i.kind), containsAll([
        AssetLicenseIssueKind.incomplete,
        AssetLicenseIssueKind.disallowedLicense,
      ]));
    });
  });
}
