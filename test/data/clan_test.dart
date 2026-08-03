import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/clan.dart';

void main() {
  group('clanBotContributionForWeek', () {
    test('cùng input → cùng output (deterministic)', () {
      expect(
        clanBotContributionForWeek(5, 2),
        clanBotContributionForWeek(5, 2),
      );
    });

    test('nằm trong khoảng 150-399', () {
      for (var week = 0; week < 20; week++) {
        for (var bot = 0; bot < kClanMemberNames.length; bot++) {
          final v = clanBotContributionForWeek(week, bot);
          expect(v, greaterThanOrEqualTo(150));
          expect(v, lessThanOrEqualTo(399));
        }
      }
    });

    test('đổi mỗi tuần (không cố định)', () {
      final w0 = clanBotContributionForWeek(0, 0);
      final w1 = clanBotContributionForWeek(1, 0);
      expect(w0 == w1, isFalse);
    });
  });

  group('clanPoolTotal', () {
    test('cộng đúng đóng góp NPC + người chơi', () {
      const week = 3;
      const playerContribution = 250;
      var expected = playerContribution;
      for (var i = 0; i < kClanMemberNames.length; i++) {
        expected += clanBotContributionForWeek(week, i);
      }
      expect(clanPoolTotal(week, playerContribution), expected);
    });

    test('người chơi đóng góp 0 vẫn cộng đủ tổng NPC', () {
      const week = 7;
      var expectedBotSum = 0;
      for (var i = 0; i < kClanMemberNames.length; i++) {
        expectedBotSum += clanBotContributionForWeek(week, i);
      }
      expect(clanPoolTotal(week, 0), expectedBotSum);
    });
  });
}
