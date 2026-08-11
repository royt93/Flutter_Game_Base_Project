import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/daily_challenge_leaderboard_bots.dart';
import 'package:pop_star_blast/data/gauntlet_leaderboard_bots.dart';
import 'package:pop_star_blast/data/leaderboard_bots.dart';
import 'package:pop_star_blast/data/weekly_featured_leaderboard_bots.dart';
import 'package:pop_star_blast/logic/leaderboard.dart';

/// T3 — 4 bảng bot có **cùng hình dạng dữ liệu** nhưng thang điểm khác nhau
/// (tổng sao campaign vs điểm 1 ván). Gộp vào 1 file, kiểm bằng 1 hàm dùng
/// chung thay vì 4 file na ná nhau.
///
/// Điều quan trọng nhất: bảng phải phủ dải hợp lý để `buildLeaderboard` xếp
/// hạng có nghĩa — người chơi mới không được đứng nhất, người chơi giỏi không
/// được đứng bét.
const _tables = <String, List<LeaderboardEntry>>{
  'kLeaderboardBots': kLeaderboardBots,
  'kDailyChallengeLeaderboardBots': kDailyChallengeLeaderboardBots,
  'kGauntletLeaderboardBots': kGauntletLeaderboardBots,
  'kWeeklyFeaturedLeaderboardBots': kWeeklyFeaturedLeaderboardBots,
};

void main() {
  _tables.forEach((name, bots) {
    group(name, () {
      test('đủ nhiều để xếp hạng có nghĩa', () {
        expect(bots.length, greaterThanOrEqualTo(5));
      });

      test('tên không rỗng và không trùng', () {
        final names = bots.map((b) => b.name).toList();
        expect(names.every((n) => n.trim().isNotEmpty), isTrue);
        expect(names.toSet().length, names.length, reason: 'tên trùng: $names');
      });

      test('điểm giảm dần nghiêm ngặt — không trùng, không đảo', () {
        for (var i = 1; i < bots.length; i++) {
          expect(
            bots[i].stars,
            lessThan(bots[i - 1].stars),
            reason:
                '$name[$i] (${bots[i].name}=${bots[i].stars}) không nhỏ hơn '
                'phần tử trước (${bots[i - 1].stars})',
          );
        }
      });

      test('mọi điểm đều dương', () {
        for (final b in bots) {
          expect(b.stars, greaterThan(0), reason: 'bot "${b.name}"');
        }
      });

      test('không bot nào bị đánh dấu isPlayer', () {
        for (final b in bots) {
          expect(
            b.isPlayer,
            isFalse,
            reason: 'bot "${b.name}" giả làm người chơi → highlight sai hàng',
          );
        }
      });

      test('phủ dải rộng — mốc thấp nhất không quá gần mốc cao nhất', () {
        final top = bots.first.stars;
        final bottom = bots.last.stars;
        expect(
          bottom * 4,
          lessThanOrEqualTo(top),
          reason:
              'dải quá hẹp ($bottom..$top) thì gần như mọi người chơi đều rơi '
              'vào cùng một hạng',
        );
      });

      test('người chơi 0 điểm → xếp bét, không nhất', () {
        final board = buildLeaderboard(bots, 0);
        expect(board.last.isPlayer, isTrue);
        expect(board.length, bots.length + 1);
      });

      test('người chơi vượt bot đầu bảng → xếp nhất', () {
        final board = buildLeaderboard(bots, bots.first.stars + 1);
        expect(board.first.isPlayer, isTrue);
      });

      test('người chơi bằng điểm bot → bot đứng trước (ổn định)', () {
        final board = buildLeaderboard(bots, bots.first.stars);
        expect(
          board.first.isPlayer,
          isFalse,
          reason: 'bằng điểm thì bot giữ hạng trên, theo doc buildLeaderboard',
        );
        expect(board[1].isPlayer, isTrue);
      });

      test('chèn người chơi không làm mất/nhân bản bot nào', () {
        final board = buildLeaderboard(bots, 12345);
        final botNames = board
            .where((e) => !e.isPlayer)
            .map((e) => e.name)
            .toList();
        expect(botNames.toSet(), bots.map((b) => b.name).toSet());
        expect(botNames.length, bots.length);
      });

      test('kết quả luôn sắp xếp giảm dần', () {
        for (final playerStars in [0, bots.last.stars, bots.first.stars * 2]) {
          final board = buildLeaderboard(bots, playerStars);
          for (var i = 1; i < board.length; i++) {
            expect(
              board[i].stars,
              lessThanOrEqualTo(board[i - 1].stars),
              reason: 'sai thứ tự với playerStars=$playerStars',
            );
          }
        }
      });
    });
  });

  group('so sánh giữa các bảng', () {
    test('4 bảng là 4 object khác nhau, không vô tình dùng chung', () {
      final tables = _tables.values.toList();
      for (var i = 0; i < tables.length; i++) {
        for (var j = i + 1; j < tables.length; j++) {
          expect(
            identical(tables[i], tables[j]),
            isFalse,
            reason: 'hai bảng trỏ cùng một list — thang điểm sẽ sai ở 1 mode',
          );
        }
      }
    });

    test('thang điểm campaign thấp hơn hẳn thang điểm theo ván', () {
      // `kLeaderboardBots` là TỔNG SAO campaign (trần ~kLevelCount*3), còn các
      // bảng kia là ĐIỂM 1 ván (hàng nghìn). Trộn nhầm bảng giữa 2 nhóm này là
      // lỗi âm thầm — bảng xếp hạng vẫn hiện, chỉ vô nghĩa.
      expect(
        kLeaderboardBots.first.stars,
        lessThan(kDailyChallengeLeaderboardBots.first.stars),
      );
    });
  });
}
