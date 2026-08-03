import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/board_frames.dart';

void main() {
  test('treasure relic frame unlocks only after expedition completion', () {
    final frame = kBoardFrames.firstWhere((f) => f.id == 'treasure_relic');
    expect(isBoardFrameUnlocked(frame, 0, {}), isFalse);
    expect(
      isBoardFrameUnlocked(frame, 0, {}, treasureMapCompleted: true),
      isTrue,
    );
  });

  group('isBoardFrameUnlocked', () {
    test('classic luôn mở khoá bất kể prestigeTier/achievement', () {
      final classic = kBoardFrames.firstWhere((f) => f.id == 'classic');
      expect(isBoardFrameUnlocked(classic, 0, {}), isTrue);
      expect(isBoardFrameUnlocked(classic, 999, {'clear_400'}), isTrue);
    });

    test('kind prestigeTier chỉ mở khoá khi prestigeTier >= ngưỡng', () {
      for (final frame in kBoardFrames.where(
        (f) => f.unlockKind == BoardFrameUnlockKind.prestigeTier,
      )) {
        expect(
          isBoardFrameUnlocked(frame, frame.requiredPrestigeTier - 1, {}),
          isFalse,
          reason: '${frame.id}: dưới ngưỡng vẫn coi là mở khoá',
        );
        expect(
          isBoardFrameUnlocked(frame, frame.requiredPrestigeTier, {}),
          isTrue,
          reason: '${frame.id}: đúng ngưỡng phải mở khoá',
        );
        expect(
          isBoardFrameUnlocked(frame, frame.requiredPrestigeTier + 5, {}),
          isTrue,
          reason: '${frame.id}: vượt ngưỡng phải mở khoá',
        );
      }
    });

    test(
      'kind achievement chỉ mở khoá khi có id trong unlockedAchievementIds',
      () {
        final diamond = kBoardFrames.firstWhere(
          (f) => f.unlockKind == BoardFrameUnlockKind.achievement,
        );
        expect(isBoardFrameUnlocked(diamond, 999, {}), isFalse);
        expect(isBoardFrameUnlocked(diamond, 999, {'other_id'}), isFalse);
        expect(
          isBoardFrameUnlocked(diamond, 0, {diamond.requiredAchievementId}),
          isTrue,
        );
      },
    );

    test('5 frame, id không trùng nhau', () {
      expect(kBoardFrames.length, 5);
      expect(kBoardFrames.map((f) => f.id).toSet().length, 5);
    });
  });
}
