import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/daily_challenge.dart';
import 'package:pop_star_blast/logic/ghost_duel.dart';
import 'package:pop_star_blast/logic/replay.dart';

/// F16 Ghost Duel — codec + mô phỏng ghost.
///
/// Hai bất biến quan trọng nhất:
/// 1. **Bàn tất định từ seed** — hai người phải chơi ĐÚNG một bàn, nếu không
///    so điểm là vô nghĩa.
/// 2. **Mã hỏng không treo** ([[X25]]) — mã đến từ bạn bè/QR/internet.
DuelData _duel({
  int seed = 12345,
  List<(int, int)> taps = const [(0, 0)],
  int score = 500,
  String name = 'Roy',
}) => DuelData(seed: seed, taps: taps, score: score, senderName: name);

void main() {
  group('codec', () {
    test('round-trip giữ nguyên mọi field', () {
      final d = _duel(taps: const [(0, 0), (3, 4), (8, 7)]);
      final back = decodeDuelCode(encodeDuelCode(d))!;

      expect(back.seed, d.seed);
      expect(back.score, d.score);
      expect(back.senderName, d.senderName);
      expect(back.taps, d.taps);
    });

    test('tên chứa dấu "|" vẫn nguyên vẹn', () {
      // `senderName` là field cuối và không split hết — cùng thủ thuật
      // `challenge_code.dart` dùng.
      final d = _duel(name: 'a|b|c');
      expect(decodeDuelCode(encodeDuelCode(d))!.senderName, 'a|b|c');
    });

    test('tên rỗng vẫn decode được', () {
      expect(decodeDuelCode(encodeDuelCode(_duel(name: '')))!.senderName, '');
    });

    test('không có tap nào vẫn hợp lệ', () {
      final back = decodeDuelCode(encodeDuelCode(_duel(taps: const [])))!;
      expect(back.taps, isEmpty);
    });

    test('mã duel KHÔNG lẫn với mã replay/challenge', () {
      final code = encodeDuelCode(_duel());
      expect(code.startsWith(duelCodePrefix), isTrue);
      expect(decodeReplay(code), isNull, reason: 'không được decode nhầm');
    });

    group('mã hỏng -> null, không ném', () {
      for (final bad in [
        '',
        'rac',
        'DU:',
        'DU:khong-phai-base64!!!',
        'CH:abc',
      ]) {
        test('"$bad"', () {
          expect(decodeDuelCode(bad), isNull);
        });
      }

      test('thiếu cột', () {
        // seed|score nhưng thiếu taps và name.
        expect(decodeDuelCode('DU:${_b64("1|2")}'), isNull);
      });

      test('seed/score âm -> null', () {
        expect(decodeDuelCode('DU:${_b64("-1|5|0,0|x")}'), isNull);
        expect(decodeDuelCode('DU:${_b64("1|-5|0,0|x")}'), isNull);
      });

      test('tap sai định dạng -> null', () {
        expect(decodeDuelCode('DU:${_b64("1|5|abc|x")}'), isNull);
        expect(decodeDuelCode('DU:${_b64("1|5|0,0,0|x")}'), isNull);
      });

      test('mã dài quá trần -> null trước khi decode', () {
        expect(decodeDuelCode('DU:${'A' * (kMaxCodeLength + 10)}'), isNull);
      });

      test('quá nhiều tap -> null', () {
        final taps = List.generate(kMaxReplayTaps + 1, (_) => '0,0').join(';');
        expect(decodeDuelCode('DU:${_b64("1|5|$taps|x")}'), isNull);
      });
    });
  });

  group('bàn tất định từ seed', () {
    test('cùng seed -> cùng bàn', () {
      final a = generateDailyChallengeGrid(777);
      final b = generateDailyChallengeGrid(777);
      expect(a, equals(b));
    });

    test('seed khác -> bàn khác', () {
      expect(
        generateDailyChallengeGrid(1),
        isNot(equals(generateDailyChallengeGrid(2))),
      );
    });
  });

  group('mô phỏng điểm ghost', () {
    test('không tap nào -> timeline rỗng', () {
      expect(ghostScoreTimeline(generateDailyChallengeGrid(1), const []),
          isEmpty);
    });

    test('điểm không bao giờ giảm', () {
      final grid = generateDailyChallengeGrid(42);
      final taps = [
        for (var r = 0; r < 8; r++)
          for (var c = 0; c < 6; c++) (r, c),
      ];
      final tl = ghostScoreTimeline(grid, taps);

      for (var i = 1; i < tl.length; i++) {
        expect(tl[i], greaterThanOrEqualTo(tl[i - 1]), reason: 'bước $i');
      }
    });

    test('timeline dài đúng bằng số tap, kể cả tap hỏng', () {
      final grid = generateDailyChallengeGrid(42);
      final taps = [(0, 0), (999, 999), (-1, -1), (1, 1)];
      expect(ghostScoreTimeline(grid, taps).length, taps.length);
    });

    test('tap ngoài bàn không ném và không cộng điểm', () {
      final grid = generateDailyChallengeGrid(42);
      final tl = ghostScoreTimeline(grid, const [(999, 999)]);
      expect(tl, [0]);
    });

    test('KHÔNG sửa bàn được truyền vào', () {
      final grid = generateDailyChallengeGrid(42);
      final before = grid.map((r) => List<int?>.from(r)).toList();
      ghostScoreTimeline(grid, const [(0, 0), (1, 1), (2, 2)]);
      expect(grid, equals(before));
    });

    test('tất định: chạy lại cùng input ra cùng timeline', () {
      final grid = generateDailyChallengeGrid(9);
      const taps = [(0, 0), (2, 2), (4, 4)];
      expect(
        ghostScoreTimeline(grid, taps),
        equals(ghostScoreTimeline(grid, taps)),
      );
    });
  });

  group('điểm ghost theo nước đi', () {
    final tl = [10, 30, 60];

    test('trước nước đầu -> 0', () {
      expect(ghostScoreAtMove(tl, -1), 0);
    });

    test('đúng từng mốc', () {
      expect(ghostScoreAtMove(tl, 0), 10);
      expect(ghostScoreAtMove(tl, 1), 30);
      expect(ghostScoreAtMove(tl, 2), 60);
    });

    test('người chơi đi nhiều nước hơn ghost -> giữ điểm cuối', () {
      // Không được biến mất: người chơi chậm vẫn phải thấy vạch đích.
      expect(ghostScoreAtMove(tl, 99), 60);
    });

    test('timeline rỗng -> 0', () {
      expect(ghostScoreAtMove(const [], 5), 0);
    });
  });

  group('kết quả trận', () {
    test('hơn điểm -> thắng', () {
      expect(ghostDuelOutcome(playerScore: 10, ghostScore: 5), GhostDuelOutcome.win);
    });
    test('kém điểm -> thua', () {
      expect(ghostDuelOutcome(playerScore: 5, ghostScore: 10), GhostDuelOutcome.lose);
    });
    test('bằng điểm -> hoà', () {
      expect(ghostDuelOutcome(playerScore: 7, ghostScore: 7), GhostDuelOutcome.draw);
    });
  });
}

String _b64(String raw) => base64Url.encode(utf8.encode(raw));
