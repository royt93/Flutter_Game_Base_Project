import 'package:flutter/foundation.dart';
import 'battle_pass.dart' show RewardKind;

/// Album sưu tập (Wave 14) — sổ gem/sticker mở khoá VĨNH VIỄN qua chơi (không
/// theo tuần như Season). Mỗi màn thắng → +điểm album (lifetime); đạt mốc tích
/// luỹ → mở 1 ô (nhận thưởng nhỏ + lộ hình). Coin-sink nhẹ + động lực sưu tập.

/// Điểm album nhận khi thắng 1 màn: nền 3 + 2 mỗi sao.
int collectionPointsForWin(int stars) => 3 + stars * 2;

@immutable
class CollectionItem {
  final String id;
  final String nameKey; // key i18n tên sticker
  final int threshold; // điểm tích luỹ để mở
  final RewardKind kind; // thưởng khi mở
  final int amount;
  final int colorIndex; // 0..5 → màu gem (độ hiếm/biểu trưng)
  const CollectionItem(
    this.id,
    this.nameKey,
    this.threshold,
    this.kind,
    this.amount,
    this.colorIndex,
  );
}

/// 12 sticker album — ngưỡng tích luỹ tăng dần, thưởng xen kẽ xu/booster.
const List<CollectionItem> kCollectionItems = [
  CollectionItem('cyan_spark', 'coll_cyan_spark', 30, RewardKind.coins, 40, 0),
  CollectionItem('magenta_bloom', 'coll_magenta_bloom', 80, RewardKind.coins, 50, 1),
  CollectionItem('lime_leaf', 'coll_lime_leaf', 150, RewardKind.hammer, 1, 2),
  CollectionItem('amber_sun', 'coll_amber_sun', 240, RewardKind.coins, 80, 3),
  CollectionItem('orange_ember', 'coll_orange_ember', 350, RewardKind.moves, 1, 4),
  CollectionItem('violet_dusk', 'coll_violet_dusk', 480, RewardKind.coins, 110, 5),
  CollectionItem('prism_shard', 'coll_prism_shard', 640, RewardKind.color, 1, 0),
  CollectionItem('nebula_core', 'coll_nebula_core', 820, RewardKind.coins, 160, 1),
  CollectionItem('aurora_wing', 'coll_aurora_wing', 1030, RewardKind.joker, 1, 2),
  CollectionItem('quasar_eye', 'coll_quasar_eye', 1280, RewardKind.coins, 220, 3),
  CollectionItem('pulsar_heart', 'coll_pulsar_heart', 1560, RewardKind.lightning, 1, 4),
  CollectionItem('singularity', 'coll_singularity', 1880, RewardKind.royal, 1, 5),
];
