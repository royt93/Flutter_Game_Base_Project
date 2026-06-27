import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/leaderboard_engine.dart';

void main() {
  group('lbBotScore — tất định + dải hợp lý', () {
    test('cùng input → cùng output (no Random)', () {
      for (var r = 0; r < kLbBotCount; r++) {
        expect(lbBotScore(2000, r, 100), lbBotScore(2000, r, 100));
      }
    });

    test('trong dải ~0.4×–1.3× target', () {
      const target = 2000;
      for (var period = 0; period < 60; period++) {
        for (var r = 0; r < kLbBotCount; r++) {
          final s = lbBotScore(target, r, period);
          expect(s, greaterThanOrEqualTo((target * 0.4 * 0.75).floor()));
          expect(s, lessThanOrEqualTo((target * 1.30).ceil()));
        }
      }
    });

    test('baseTarget <= 0 → fallback 1000, không lỗi/0', () {
      expect(lbBotScore(0, 0, 5), greaterThan(0));
      expect(lbBotScore(-50, 3, 5), greaterThan(0));
    });

    test('period khác → điểm khác (bảng đổi theo chu kỳ)', () {
      final a = [for (var r = 0; r < kLbBotCount; r++) lbBotScore(2000, r, 10)];
      final b = [for (var r = 0; r < kLbBotCount; r++) lbBotScore(2000, r, 11)];
      expect(a, isNot(equals(b)));
    });
  });

  group('lbBotName — distinct trong cùng bảng', () {
    test('9 bot không trùng tên', () {
      for (var period = 0; period < 30; period++) {
        final names = {
          for (var r = 0; r < kLbBotCount; r++) lbBotName(r, period),
        };
        expect(names.length, kLbBotCount);
      }
    });
  });

  group('buildLeaderboard', () {
    test('top tối đa 10, giảm dần', () {
      final b = buildLeaderboard(2000, 1800, 7);
      expect(b.length, lessThanOrEqualTo(10));
      for (var i = 1; i < b.length; i++) {
        expect(b[i - 1].score, greaterThanOrEqualTo(b[i].score));
      }
    });

    test('người chơi điểm cao → hạng 1', () {
      final b = buildLeaderboard(2000, 999999, 7);
      expect(playerRank(b), 1);
    });

    test('người chơi điểm 0 → có mặt nhưng hạng chót dải', () {
      final b = buildLeaderboard(2000, 0, 7);
      expect(playerRank(b), greaterThan(0));
    });

    test('includePlayer=false → chỉ bot, không dòng người chơi', () {
      final b = buildLeaderboard(2000, 1500, 7, includePlayer: false);
      expect(playerRank(b), 0);
      expect(b.every((e) => !e.isPlayer), isTrue);
    });

    test('playerScore < 0 → ẩn người chơi', () {
      final b = buildLeaderboard(2000, -1, 7);
      expect(playerRank(b), 0);
    });

    test('tie-break: người chơi đứng TRÊN bot cùng điểm', () {
      // chọn điểm trùng bot hạng 0 ở period cố định
      const period = 7;
      final botTop = lbBotScore(2000, 0, period);
      final b = buildLeaderboard(2000, botTop, period);
      final pr = playerRank(b);
      expect(pr, greaterThan(0));
      // mọi bot có CÙNG điểm với người chơi phải xếp SAU người chơi
      final playerIdx = pr - 1;
      for (var i = 0; i < b.length; i++) {
        if (!b[i].isPlayer && b[i].score == botTop) {
          expect(
            i,
            greaterThan(playerIdx),
            reason: 'bot cùng điểm phải đứng sau người chơi',
          );
        }
      }
    });
  });
}
