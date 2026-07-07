import 'package:flutter/foundation.dart';
import 'cosmetics.dart' show kGemSkins, GemSkin;

/// Album sưu tập (Wave 14, đổi vai W18.2) — sổ gem/sticker mở khoá VĨNH VIỄN qua
/// chơi. W18.2: sticker là VẬT SƯU TẬP thuần (KHÔNG còn thưởng xu/booster lặp lại
/// — hết trùng với Thành tựu); hoàn tất CẢ BỘ → thưởng LỚN 1 lần (perk cosmetic:
/// mở khoá skin gem độc quyền + ít xu). Giá trị = sưu tập + cosmetic, không p2w.

/// Điểm album nhận khi thắng 1 màn: nền 3 + 2 mỗi sao.
int collectionPointsForWin(int stars) => 3 + stars * 2;

/// Phần thưởng HOÀN TẤT BỘ (nhận 1 lần): mở khoá skin gem độc quyền + xu.
const String kCollectionSetSkin = 'void'; // skin cao cấp nhất (xem kGemSkins)
const int kCollectionSetCoins = 200;

/// Giá bù đắp khi player đã mua [kCollectionSetSkin] từ Shop trước khi hoàn Album.
/// Đọc giá trực tiếp từ kGemSkins → tự đồng bộ nếu giá skin thay đổi sau này.
GemSkin? get kCollectionSetSkinDef =>
    kGemSkins.where((s) => s.id == kCollectionSetSkin).firstOrNull;
int get kCollectionSetSkinPrice => kCollectionSetSkinDef?.price ?? 900;

@immutable
class CollectionItem {
  final String id;
  final String nameKey; // key i18n tên sticker
  final String descKey; // key i18n mô tả ngắn (W27.3)
  final int threshold; // điểm tích luỹ để mở
  final int colorIndex; // 0..5 → màu gem (độ hiếm/biểu trưng)
  const CollectionItem(
    this.id,
    this.nameKey,
    this.descKey,
    this.threshold,
    this.colorIndex,
  );
}

/// 12 sticker album — ngưỡng tích luỹ tăng dần (vật sưu tập, không thưởng riêng).
const List<CollectionItem> kCollectionItems = [
  CollectionItem(
    'cyan_spark',
    'coll_cyan_spark',
    'coll_desc_cyan_spark',
    30,
    0,
  ),
  CollectionItem(
    'magenta_bloom',
    'coll_magenta_bloom',
    'coll_desc_magenta_bloom',
    80,
    1,
  ),
  CollectionItem('lime_leaf', 'coll_lime_leaf', 'coll_desc_lime_leaf', 150, 2),
  CollectionItem('amber_sun', 'coll_amber_sun', 'coll_desc_amber_sun', 240, 3),
  CollectionItem(
    'orange_ember',
    'coll_orange_ember',
    'coll_desc_orange_ember',
    350,
    4,
  ),
  CollectionItem(
    'violet_dusk',
    'coll_violet_dusk',
    'coll_desc_violet_dusk',
    480,
    5,
  ),
  CollectionItem(
    'prism_shard',
    'coll_prism_shard',
    'coll_desc_prism_shard',
    640,
    0,
  ),
  CollectionItem(
    'nebula_core',
    'coll_nebula_core',
    'coll_desc_nebula_core',
    820,
    1,
  ),
  CollectionItem(
    'aurora_wing',
    'coll_aurora_wing',
    'coll_desc_aurora_wing',
    1030,
    2,
  ),
  CollectionItem(
    'quasar_eye',
    'coll_quasar_eye',
    'coll_desc_quasar_eye',
    1280,
    3,
  ),
  CollectionItem(
    'pulsar_heart',
    'coll_pulsar_heart',
    'coll_desc_pulsar_heart',
    1560,
    4,
  ),
  CollectionItem(
    'singularity',
    'coll_singularity',
    'coll_desc_singularity',
    1880,
    5,
  ),
];
