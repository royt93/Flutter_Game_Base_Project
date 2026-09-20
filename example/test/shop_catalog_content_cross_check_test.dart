import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/remote_content_pack.dart';
import 'package:roy_casual_kit_example/generated/shop_catalog_content.g.dart';

/// Same fake-bundle convention as
/// `test/core/remote_content_pack_test.dart` in the root package.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key];
    if (content == null) throw Exception('Asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

const _assetPath = 'assets/shop_catalog_fallback.json';
const _fixtureJson =
    '{"title":"Sword","price":100,"onSale":true,"schemaVersion":1}';

void main() {
  // FEAT-81: cùng 1 fixture, đi qua đường "asset fallback" (RemoteContentPack
  // đọc từ bundled asset, cơ chế IDEA-37 đã có sẵn) và đường "generated
  // content" (gọi thẳng ShopCatalogContent.fromJson — model do
  // tool/remote_schema_compiler.dart sinh từ example/remote_schemas/shop_catalog.schema.json)
  // phải cho ra CÙNG 1 kết quả semantic — chứng minh model sinh ra tương
  // thích thật với runtime path hiện có, không chỉ đúng trên giấy.
  test(
    'asset fallback (RemoteContentPack) và generated content (ShopCatalogContent.fromJson) '
    'ra cùng kết quả cho cùng 1 fixture',
    () async {
      final pack = RemoteContentPack<ShopCatalogContent>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: ShopCatalogContent.fromJson,
        bundle: _FakeAssetBundle({_assetPath: _fixtureJson}),
      );

      final viaAssetFallback = await pack.load();
      final viaGeneratedContent = ShopCatalogContent.fromJson(
        jsonDecode(_fixtureJson) as Map<String, Object?>,
      );

      expect(viaAssetFallback, isNotNull);
      expect(viaAssetFallback, viaGeneratedContent);
      expect(viaAssetFallback!.title, 'Sword');
      expect(viaAssetFallback.price, 100);
      expect(viaAssetFallback.onSale, isTrue);
    },
  );
}
