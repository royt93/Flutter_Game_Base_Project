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

  // I24 (task #14): World 11 (level 201-220) — world mới nhất, phải khớp
  // đúng range đã khai báo trong kWorlds và có màu/icon riêng (không trùng
  // 10 world trước).
  group('World 11', () {
    test('startId 201, endId 220, nameKey world_path_name_11', () {
      final w11 = kWorlds.last;
      expect(w11.startId, 201);
      expect(w11.endId, 220);
      expect(w11.nameKey, 'world_path_name_11');
    });

    test('màu không trùng bất kỳ world nào trong 10 world trước', () {
      final earlierColors = kWorlds
          .sublist(0, kWorlds.length - 1)
          .map((w) => w.color)
          .toSet();
      expect(earlierColors.contains(kWorlds.last.color), isFalse);
    });
  });
}
