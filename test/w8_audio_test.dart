import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/audio_manager.dart';

void main() {
  group('Giai điệu — noteIndexFor (ngũ cung + màu + khoá)', () {
    test('mọi nốt nằm trong dải hợp lệ 1..24', () {
      for (int combo = 1; combo <= 40; combo++) {
        for (int color = -1; color < 6; color++) {
          for (int key = 1; key <= 5; key++) {
            final n = AudioManager.noteIndexFor(
                combo: combo, colorIndex: color, keyIndex: key);
            expect(n, inInclusiveRange(1, AudioManager.noteCount));
          }
        }
      }
    });

    test('combo theo thang NGŨ CUNG (root key=1, không màu)', () {
      // combo 1..5 → bậc 0..4 của pentatonic [0,2,4,7,9] → nốt 1,3,5,8,10
      final expected = [1, 3, 5, 8, 10];
      for (int c = 1; c <= 5; c++) {
        expect(
            AudioManager.noteIndexFor(combo: c, keyIndex: 1), expected[c - 1]);
      }
      // combo 6 → lên quãng tám: bậc 5 → 12 bán cung → nốt 13
      expect(AudioManager.noteIndexFor(combo: 6, keyIndex: 1), 13);
    });

    test('MÀU gem đổi bậc gốc → nốt khác nhau ở cùng combo', () {
      final byColor = [
        for (int c = 0; c < 5; c++)
          AudioManager.noteIndexFor(combo: 1, colorIndex: c, keyIndex: 1)
      ];
      // 5 màu đầu → 5 bậc ngũ cung phân biệt
      expect(byColor.toSet().length, 5);
      expect(byColor, [1, 3, 5, 8, 10]);
    });

    test('KHOÁ (world/stage) dịch tông', () {
      final k1 = AudioManager.noteIndexFor(combo: 1, keyIndex: 1); // root 0 → 1
      final k2 = AudioManager.noteIndexFor(combo: 1, keyIndex: 2); // root 2 → 3
      final k4 = AudioManager.noteIndexFor(combo: 1, keyIndex: 4); // root 5 → 6
      expect(k1, 1);
      expect(k2, 3);
      expect(k4, 6);
    });

    test('mọi nốt phát ra đều thuộc thang ngũ cung của khoá đó', () {
      bool inPenta(int semitoneFromRoot) =>
          AudioManager.pentatonic.contains(semitoneFromRoot % 12);
      for (int key = 1; key <= 5; key++) {
        final root = AudioManager.keyRoots[(key - 1) % 5];
        for (int c = 1; c <= 12; c++) {
          final n = AudioManager.noteIndexFor(combo: c, keyIndex: key);
          final semitone = (n - 1) - root;
          // bỏ qua trường hợp bị clamp ở đỉnh dải (nốt 24)
          if (n < AudioManager.noteCount) {
            expect(inPenta(semitone), isTrue,
                reason: 'key=$key combo=$c nốt=$n ngoài ngũ cung');
          }
        }
      }
    });
  });
}
