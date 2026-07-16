import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/audio_manager.dart';

void main() {
  group('AudioManager.bgmTierFor (I12 — nhạc thêm lớp theo combo)', () {
    test('combo thấp (<3) → track nền (0)', () {
      expect(AudioManager.bgmTierFor(0), 0);
      expect(AudioManager.bgmTierFor(2), 0);
    });

    test('combo vừa (3..5) → track lớp 1', () {
      expect(AudioManager.bgmTierFor(3), 1);
      expect(AudioManager.bgmTierFor(5), 1);
    });

    test('combo cao (>=6, wombo) → track lớp 2', () {
      expect(AudioManager.bgmTierFor(6), 2);
      expect(AudioManager.bgmTierFor(20), 2);
    });
  });
}
