import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/worlds.dart';

void main() {
  group('kWorlds', () {
    test('range liên tục, không chồng/hở, phủ đúng 1..kLevelCount', () {
      var expectedStart = 1;
      for (final w in kWorlds) {
        expect(w.startId, expectedStart);
        expect(w.endId, greaterThanOrEqualTo(w.startId));
        expectedStart = w.endId + 1;
      }
      expect(expectedStart - 1, kLevelCount);
    });

    test('nameKey không trùng nhau giữa các world', () {
      final keys = kWorlds.map((w) => w.nameKey).toSet();
      expect(keys.length, kWorlds.length);
    });
  });

  group('worldForLevel', () {
    test('mọi level id map đúng world chứa nó', () {
      for (final w in kWorlds) {
        expect(worldForLevel(w.startId), same(w));
        expect(worldForLevel(w.endId), same(w));
      }
    });

    test('id ngoài phạm vi (âm/quá lớn) fallback về world cuối', () {
      expect(worldForLevel(-1), same(kWorlds.last));
      expect(worldForLevel(999999), same(kWorlds.last));
    });
  });

  // I24 (task #14): World 11 (level 201-220) — không còn là world cuối kể từ
  // Round-7 (World 12), dùng index cố định thay vì `kWorlds.last`.
  group('World 11', () {
    test('startId 201, endId 220, nameKey world_path_name_11', () {
      final w11 = kWorlds[10];
      expect(w11.startId, 201);
      expect(w11.endId, 220);
      expect(w11.nameKey, 'world_path_name_11');
    });

    test('màu không trùng bất kỳ world nào khác', () {
      final otherColors = kWorlds
          .where((w) => w.nameKey != 'world_path_name_11')
          .map((w) => w.color)
          .toSet();
      expect(otherColors.contains(kWorlds[10].color), isFalse);
    });
  });

  // Round-7: World 12 "Aurora Comet Trail" (level 221-240) — world mới
  // nhất, phải khớp đúng range đã khai báo trong kWorlds và có màu/icon
  // riêng (không trùng 11 world trước).
  group('World 12', () {
    test('startId 221, endId 240, nameKey world_path_name_12', () {
      final w12 = kWorlds.last;
      expect(w12.startId, 221);
      expect(w12.endId, 240);
      expect(w12.nameKey, 'world_path_name_12');
    });

    test('màu không trùng bất kỳ world nào trong 11 world trước', () {
      final earlierColors = kWorlds
          .sublist(0, kWorlds.length - 1)
          .map((w) => w.color)
          .toSet();
      expect(earlierColors.contains(kWorlds.last.color), isFalse);
    });
  });
}
