import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/leaderboard.dart';

void main() {
  const bots = [
    LeaderboardEntry('A', 500),
    LeaderboardEntry('B', 300),
    LeaderboardEntry('C', 100),
  ];

  test('chèn đúng vị trí giữa 2 bot theo sao giảm dần', () {
    final entries = buildLeaderboard(bots, 250);
    expect(entries.map((e) => e.name), ['A', 'B', '__player__', 'C']);
    expect(playerRank(entries), 3);
  });

  test('điểm cao nhất → hạng 1', () {
    final entries = buildLeaderboard(bots, 999);
    expect(playerRank(entries), 1);
  });

  test('điểm thấp nhất → hạng cuối', () {
    final entries = buildLeaderboard(bots, 0);
    expect(playerRank(entries), 4);
  });

  test('bằng điểm bot → bot đứng trước (tie-break ổn định)', () {
    final entries = buildLeaderboard(bots, 300);
    expect(entries.map((e) => e.name), ['A', 'B', '__player__', 'C']);
    expect(playerRank(entries), 3);
  });
}
