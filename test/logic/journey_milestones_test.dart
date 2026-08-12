import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/milestone_journal.dart';

/// I87 — `pickJourneyMilestones`: chọn mốc in lên thẻ chia sẻ.
///
/// Thuần và tất định. Hai luật cần khoá chặt:
/// 1. mỗi `MilestoneKind` nhiều nhất một dòng — nếu không, người chơi lâu năm
///    có hàng chục achievement cùng ngày sẽ đẩy hết mọi loại khác ra ngoài và
///    thẻ nào cũng giống thẻ nào;
/// 2. thành tựu xếp trước, phần còn lại theo thời gian.
MilestoneEntry _e(MilestoneKind kind, int day, [String? param]) =>
    MilestoneEntry(kind: kind, epochDay: day, param: param);

void main() {
  test('rỗng -> rỗng', () {
    expect(pickJourneyMilestones(const []), isEmpty);
  });

  test('cắt đúng số dòng tối đa', () {
    final entries = [
      for (final k in MilestoneKind.values) _e(k, 100 - k.index),
    ];
    expect(entries.length, greaterThan(kJourneyCardMilestones));

    expect(
      pickJourneyMilestones(entries).length,
      kJourneyCardMilestones,
    );
  });

  test('max = 0 -> rỗng, không ném', () {
    expect(pickJourneyMilestones([_e(MilestoneKind.dailyClaim, 5)], max: 0),
        isEmpty);
  });

  test('ít hơn trần -> giữ nguyên tất cả', () {
    final entries = [
      _e(MilestoneKind.dailyClaim, 10),
      _e(MilestoneKind.spinWheel, 9),
    ];
    expect(pickJourneyMilestones(entries).length, 2);
  });

  group('mỗi loại nhiều nhất 1 dòng', () {
    test('nhiều achievement -> chỉ lấy 1', () {
      final entries = [
        for (var i = 0; i < 20; i++)
          _e(MilestoneKind.achievementUnlocked, 100 - i, 'ach_$i'),
        _e(MilestoneKind.dailyClaim, 50),
        _e(MilestoneKind.spinWheel, 49),
      ];

      final picked = pickJourneyMilestones(entries);

      expect(
        picked.where((e) => e.kind == MilestoneKind.achievementUnlocked).length,
        1,
        reason: 'thẻ toàn achievement thì mọi thẻ trông như nhau',
      );
      expect(picked.map((e) => e.kind).toSet().length, picked.length);
    });

    test('giữ bản MỚI NHẤT của mỗi loại', () {
      // Input đã sort mới-nhất-trước như `buildMilestoneJournal` trả về.
      final entries = [
        _e(MilestoneKind.achievementUnlocked, 90, 'moi'),
        _e(MilestoneKind.achievementUnlocked, 10, 'cu'),
      ];

      expect(pickJourneyMilestones(entries).single.param, 'moi');
    });
  });

  group('thứ tự', () {
    test('thành tựu đứng trước dù cũ hơn', () {
      final entries = [
        _e(MilestoneKind.dailyClaim, 100),
        _e(MilestoneKind.achievementUnlocked, 1, 'ach'),
      ];

      expect(
        pickJourneyMilestones(entries).first.kind,
        MilestoneKind.achievementUnlocked,
        reason: 'điểm danh mới hơn không có nghĩa là đáng khoe hơn',
      );
    });

    test('trong nhóm không-thành-tựu: mới trước cũ', () {
      final entries = [
        _e(MilestoneKind.dailyClaim, 10),
        _e(MilestoneKind.spinWheel, 90),
        _e(MilestoneKind.gauntlet, 50),
      ];

      final picked = pickJourneyMilestones(entries);

      expect(picked.map((e) => e.epochDay).toList(), [90, 50, 10]);
    });

    test('cùng ngày -> vẫn tất định (không phụ thuộc sort không ổn định)', () {
      final entries = [
        _e(MilestoneKind.gauntlet, 40),
        _e(MilestoneKind.spinWheel, 40),
        _e(MilestoneKind.dailyClaim, 40),
      ];

      final a = pickJourneyMilestones(entries).map((e) => e.kind).toList();
      final b = pickJourneyMilestones(entries.reversed.toList())
          .map((e) => e.kind)
          .toList();

      expect(a, b, reason: 'cùng tập input phải luôn ra cùng thứ tự');
    });
  });

  test('không sửa danh sách đầu vào', () {
    final entries = [
      _e(MilestoneKind.dailyClaim, 10),
      _e(MilestoneKind.spinWheel, 90),
    ];
    final before = List.of(entries);

    pickJourneyMilestones(entries);

    expect(entries.map((e) => e.epochDay), before.map((e) => e.epochDay));
  });

  test('nối được thẳng từ buildMilestoneJournal', () {
    final feed = buildMilestoneJournal(
      lastLoginEpochDay: 100,
      loginStreakCount: 3,
      lastClaimDay: 99,
      lastDailyChallengeDay: 98,
      lastSpinDay: 97,
      lastGauntletDay: 96,
      raidBossLastAttemptDay: 95,
      lastFeaturedWeekSeen: 13,
      lastPetCollectTimestampMs: 94 * 86400000,
      achievementUnlockDays: const {'ach_a': 50, 'ach_b': 60},
    );

    final picked = pickJourneyMilestones(feed);

    expect(picked.length, kJourneyCardMilestones);
    expect(picked.first.kind, MilestoneKind.achievementUnlocked);
    expect(picked.map((e) => e.kind).toSet().length, picked.length);
  });
}
