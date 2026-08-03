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

    test('8 frame, id không trùng nhau', () {
      expect(kBoardFrames.length, 8);
      expect(kBoardFrames.map((f) => f.id).toSet().length, 8);
    });

    test('kind seasonal khoá ngoài khung, mở trong khung', () {
      final tet = kBoardFrames.firstWhere((f) => f.id == 'seasonal_tet');
      expect(
        isBoardFrameUnlocked(tet, 0, {}, now: DateTime(2026, 1, 19)),
        isFalse,
        reason: 'trước khung (19/1) phải khoá',
      );
      expect(
        isBoardFrameUnlocked(tet, 0, {}, now: DateTime(2026, 1, 20)),
        isTrue,
        reason: 'đúng mốc bắt đầu (20/1) phải mở',
      );
      expect(
        isBoardFrameUnlocked(tet, 0, {}, now: DateTime(2026, 2, 10)),
        isTrue,
        reason: 'đúng mốc kết thúc (10/2) phải mở',
      );
      expect(
        isBoardFrameUnlocked(tet, 0, {}, now: DateTime(2026, 2, 11)),
        isFalse,
        reason: 'sau khung (11/2) phải khoá',
      );
    });

    test('kind seasonal xử lý wrap-around qua năm mới đúng cả 2 phía', () {
      final christmas = kBoardFrames.firstWhere(
        (f) => f.id == 'seasonal_christmas',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2026, 12, 14)),
        isFalse,
        reason: 'trước khung (14/12) phải khoá',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2026, 12, 15)),
        isTrue,
        reason: 'mốc bắt đầu (15/12) phải mở',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2026, 12, 31)),
        isTrue,
        reason: '31/12 vẫn trong khung (vắt qua năm mới) phải mở',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2027, 1, 1)),
        isTrue,
        reason: '1/1 năm sau vẫn trong khung phải mở',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2027, 1, 2)),
        isTrue,
        reason: 'đúng mốc kết thúc (2/1) phải mở',
      );
      expect(
        isBoardFrameUnlocked(christmas, 0, {}, now: DateTime(2027, 1, 3)),
        isFalse,
        reason: 'sau khung (3/1) phải khoá',
      );
    });
  });
}
