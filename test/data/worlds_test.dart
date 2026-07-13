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
}
