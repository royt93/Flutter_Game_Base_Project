import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/daily_challenge.dart';

void main() {
  test('cùng seed → cùng bàn (2 lần sinh giống hệt)', () {
    final a = generateDailyChallengeGrid(100);
    final b = generateDailyChallengeGrid(100);
    expect(a, equals(b));
  });

  test('seed khác nhau → bàn khác', () {
    final a = generateDailyChallengeGrid(100);
    final b = generateDailyChallengeGrid(101);
    expect(a, isNot(equals(b)));
  });

  test('kích thước bàn đúng cấu hình', () {
    final grid = generateDailyChallengeGrid(1);
    expect(grid.length, dailyChallengeRows);
    for (final row in grid) {
      expect(row.length, dailyChallengeCols);
      for (final v in row) {
        expect(v, inInclusiveRange(0, dailyChallengeColorCount - 1));
      }
    }
  });
}
