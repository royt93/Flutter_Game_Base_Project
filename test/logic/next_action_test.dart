import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/next_action.dart';

/// I84 — bảng ưu tiên "làm gì tiếp theo".
///
/// Đây là toàn bộ luật của tính năng, nên test bám sát 3 điều: đúng thứ tự,
/// không bao giờ gợi ý thứ không nhận được, và người chơi mới không bị dội
/// 20 hệ meta vào mặt.
List<NextActionKind> _kinds(List<NextAction> actions) =>
    actions.map((a) => a.kind).toList();

/// Người chơi đã đi xa, không có gì đang chờ nhận.
List<NextAction> _rank({
  bool canClaimDailyReward = false,
  bool canClaimSpin = false,
  int questsReadyToClaim = 0,
  bool weeklyGoalReady = false,
  bool clanGoalReady = false,
  bool chestReady = false,
  bool seasonMilestoneReady = false,
  bool raidActiveToday = false,
  bool raidHasAttemptsLeft = false,
  int unlockedLevel = 50,
  int levelCount = 260,
}) => rankNextActions(
  canClaimDailyReward: canClaimDailyReward,
  canClaimSpin: canClaimSpin,
  questsReadyToClaim: questsReadyToClaim,
  weeklyGoalReady: weeklyGoalReady,
  clanGoalReady: clanGoalReady,
  chestReady: chestReady,
  seasonMilestoneReady: seasonMilestoneReady,
  raidActiveToday: raidActiveToday,
  raidHasAttemptsLeft: raidHasAttemptsLeft,
  unlockedLevel: unlockedLevel,
  levelCount: levelCount,
);

void main() {
  group('giới hạn số gợi ý', () {
    test('không bao giờ quá kMaxNextActions dù mọi thứ đều sẵn', () {
      final r = _rank(
        canClaimDailyReward: true,
        canClaimSpin: true,
        questsReadyToClaim: 3,
        weeklyGoalReady: true,
        clanGoalReady: true,
        chestReady: true,
        seasonMilestoneReady: true,
        raidActiveToday: true,
        raidHasAttemptsLeft: true,
      );
      expect(r.length, kMaxNextActions);
    });

    test('không có gì để làm -> danh sách chỉ còn campaign', () {
      expect(_kinds(_rank()), [NextActionKind.campaignLevel]);
    });

    test(
      'đã phá đảo và không còn gì chờ -> rỗng (UI tự hiện dòng thân thiện)',
      () {
        expect(_rank(unlockedLevel: 261, levelCount: 260), isEmpty);
      },
    );
  });

  group('thứ tự ưu tiên', () {
    test('hết-hạn-theo-ngày đứng trước đã-đủ-điều-kiện', () {
      final r = _kinds(
        _rank(
          canClaimDailyReward: true,
          chestReady: true,
          weeklyGoalReady: true,
        ),
      );
      expect(r.first, NextActionKind.dailyReward);
      expect(
        r.indexOf(NextActionKind.starRoadChest),
        greaterThan(r.indexOf(NextActionKind.dailyReward)),
      );
    });

    test('campaign luôn xếp cuối, không chen lên trên việc sắp hết hạn', () {
      final r = _kinds(_rank(canClaimDailyReward: true, canClaimSpin: true));
      expect(r.last, NextActionKind.campaignLevel);
    });

    test('campaign bị đẩy ra ngoài khi đã đủ 3 việc gấp hơn', () {
      final r = _kinds(
        _rank(
          canClaimDailyReward: true,
          canClaimSpin: true,
          questsReadyToClaim: 2,
        ),
      );
      expect(r, isNot(contains(NextActionKind.campaignLevel)));
      expect(r.length, kMaxNextActions);
    });
  });

  group('không gợi ý thứ không nhận được', () {
    test('đã nhận thưởng ngày hôm nay -> không gợi ý lại', () {
      expect(
        _kinds(_rank(canClaimDailyReward: false)),
        isNot(contains(NextActionKind.dailyReward)),
      );
    });

    test('raid mở nhưng hết lượt -> không gợi ý', () {
      expect(
        _kinds(_rank(raidActiveToday: true, raidHasAttemptsLeft: false)),
        isNot(contains(NextActionKind.raidBoss)),
      );
    });

    test('còn lượt nhưng ngoài cuối tuần -> không gợi ý', () {
      expect(
        _kinds(_rank(raidActiveToday: false, raidHasAttemptsLeft: true)),
        isNot(contains(NextActionKind.raidBoss)),
      );
    });

    test('không có quest nào xong -> không gợi ý quest', () {
      expect(
        _kinds(_rank(questsReadyToClaim: 0)),
        isNot(contains(NextActionKind.dailyQuest)),
      );
    });
  });

  group('người chơi mới', () {
    test('chỉ thấy thưởng ngày + campaign, không thấy hệ meta nào', () {
      final r = _kinds(
        _rank(
          unlockedLevel: 1,
          canClaimDailyReward: true,
          // Mọi thứ khác đều "sẵn sàng" — vẫn phải bị ẩn.
          canClaimSpin: true,
          questsReadyToClaim: 3,
          weeklyGoalReady: true,
          clanGoalReady: true,
          chestReady: true,
          seasonMilestoneReady: true,
          raidActiveToday: true,
          raidHasAttemptsLeft: true,
        ),
      );
      expect(r, [NextActionKind.dailyReward, NextActionKind.campaignLevel]);
    });

    test('đúng mốc cuối của "người chơi mới" vẫn còn bị ẩn', () {
      final r = _kinds(
        _rank(unlockedLevel: kNewPlayerLevelCap, chestReady: true),
      );
      expect(r, [NextActionKind.campaignLevel]);
    });

    test('vượt mốc 1 level là mở hết hệ meta', () {
      final r = _kinds(
        _rank(unlockedLevel: kNewPlayerLevelCap + 1, chestReady: true),
      );
      expect(r, contains(NextActionKind.starRoadChest));
    });
  });

  group('payload số đi kèm', () {
    test('campaign mang số màn kế tiếp', () {
      final r = _rank(unlockedLevel: 42);
      expect(
        r.single,
        const NextAction(NextActionKind.campaignLevel, value: 42),
      );
    });

    test('quest mang số quest đã xong', () {
      final r = _rank(questsReadyToClaim: 2);
      expect(r.first, const NextAction(NextActionKind.dailyQuest, value: 2));
    });

    test('mục không cần số thì value null', () {
      final r = _rank(canClaimDailyReward: true);
      expect(r.first.value, isNull);
    });
  });
}
