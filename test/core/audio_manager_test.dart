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

  group('AudioManager.noteIndexFor (I13 — cao độ SFX pop theo nhóm)', () {
    test('combo=1, colorIndex=-1, keyIndex=1 mặc định → nốt gốc (1)', () {
      expect(
        AudioManager.noteIndexFor(combo: 1, colorIndex: -1, keyIndex: 1),
        1,
      );
    });

    test('combo càng sâu → leo bậc ngũ cung (nốt tăng dần)', () {
      final notes = [
        for (var combo = 1; combo <= 8; combo++)
          AudioManager.noteIndexFor(combo: combo, colorIndex: -1, keyIndex: 1),
      ];
      for (var i = 1; i < notes.length; i++) {
        expect(
          notes[i],
          greaterThanOrEqualTo(notes[i - 1]),
          reason: 'combo ${i + 1} phải >= combo $i (leo bậc, không tụt)',
        );
      }
    });

    test('colorIndex quyết định bậc gốc khi combo=1', () {
      expect(
        AudioManager.noteIndexFor(combo: 1, colorIndex: 0, keyIndex: 1),
        1,
      );
      expect(
        AudioManager.noteIndexFor(combo: 1, colorIndex: 2, keyIndex: 1),
        5,
      );
    });

    test('keyIndex dịch nốt gốc theo khoá (world/stage)', () {
      expect(
        AudioManager.noteIndexFor(combo: 1, colorIndex: -1, keyIndex: 1),
        1,
      );
      expect(
        AudioManager.noteIndexFor(combo: 1, colorIndex: -1, keyIndex: 2),
        3,
      );
    });

    test(
      'keyIndex quay vòng theo modulo số khoá (keyIndex=6 == keyIndex=1)',
      () {
        expect(
          AudioManager.noteIndexFor(combo: 1, colorIndex: -1, keyIndex: 6),
          AudioManager.noteIndexFor(combo: 1, colorIndex: -1, keyIndex: 1),
        );
      },
    );

    test(
      'colorIndex quay vòng theo modulo số bậc (colorIndex=5 == colorIndex=0)',
      () {
        expect(
          AudioManager.noteIndexFor(combo: 1, colorIndex: 5, keyIndex: 1),
          AudioManager.noteIndexFor(combo: 1, colorIndex: 0, keyIndex: 1),
        );
      },
    );

    test('kết quả luôn trong khoảng 1..noteCount (clamp không vỡ)', () {
      for (var combo = 1; combo <= 50; combo++) {
        final idx = AudioManager.noteIndexFor(
          combo: combo,
          colorIndex: 4,
          keyIndex: 5,
        );
        expect(idx, greaterThanOrEqualTo(1));
        expect(idx, lessThanOrEqualTo(AudioManager.noteCount));
      }
    });
  });
}
