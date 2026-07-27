import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/logic/challenge_code.dart';

void main() {
  group('encodeChallengeCode / decodeChallengeCode', () {
    test('round-trip đúng', () {
      const data = ChallengeCode(levelId: 12, score: 3400, senderName: 'Roy');
      final decoded = decodeChallengeCode(encodeChallengeCode(data));
      expect(decoded, isNotNull);
      expect(decoded!.levelId, 12);
      expect(decoded.score, 3400);
      expect(decoded.senderName, 'Roy');
    });

    test('senderName có ký tự | và unicode tiếng Việt vẫn round-trip đúng', () {
      const data = ChallengeCode(
        levelId: 5,
        score: 999,
        senderName: r'Ròy|Đẹp trai',
      );
      final decoded = decodeChallengeCode(encodeChallengeCode(data));
      expect(decoded, isNotNull);
      expect(decoded!.senderName, r'Ròy|Đẹp trai');
    });

    test(
      'mã không có prefix challengeCodePrefix → null (phân biệt mã ghost-replay)',
      () {
        expect(decodeChallengeCode('không phải mã'), isNull);
      },
    );

    test('base64 sai format sau prefix → null, không throw', () {
      expect(
        decodeChallengeCode('$challengeCodePrefix!!!not-base64!!!'),
        isNull,
      );
    });

    test('thiếu cột (payload chỉ có levelId) → null', () {
      final bad = challengeCodePrefix + base64Url.encode(utf8.encode('42'));
      expect(decodeChallengeCode(bad), isNull);
    });

    test('levelId ngoài phạm vi 1..kLevelCount → null', () {
      const tooHigh = ChallengeCode(
        levelId: kLevelCount + 1,
        score: 10,
        senderName: 'X',
      );
      expect(decodeChallengeCode(encodeChallengeCode(tooHigh)), isNull);

      const zero = ChallengeCode(levelId: 0, score: 10, senderName: 'X');
      expect(decodeChallengeCode(encodeChallengeCode(zero)), isNull);
    });

    test('score âm → null', () {
      final bad =
          challengeCodePrefix + base64Url.encode(utf8.encode('5|-10|X'));
      expect(decodeChallengeCode(bad), isNull);
    });
  });
}
