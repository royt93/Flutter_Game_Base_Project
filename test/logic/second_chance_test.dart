import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/second_chance.dart';

/// I88 — điều kiện chào mua cơ hội thứ hai.
///
/// Rủi ro của tính năng này không phải crash mà là **chào sai lúc**: chào khi
/// người chơi thua bét thì bị ghét, chào ở side-mode thì mọi kỷ lục đều mua
/// được. Test bám vào đúng các điều kiện tắt đó.
bool _offer({
  bool isCampaign = true,
  int starsEarned = 0,
  int score = 100,
  int targetScore = 100,
  bool alreadyUsedThisLevel = false,
  int coins = 9999,
}) => canOfferSecondChance(
  isCampaign: isCampaign,
  starsEarned: starsEarned,
  score: score,
  targetScore: targetScore,
  alreadyUsedThisLevel: alreadyUsedThisLevel,
  coins: coins,
);

bool _unaffordable({
  bool isCampaign = true,
  int starsEarned = 0,
  int score = 100,
  int targetScore = 100,
  bool alreadyUsedThisLevel = false,
  int coins = 0,
}) => isSecondChanceUnaffordable(
  isCampaign: isCampaign,
  starsEarned: starsEarned,
  score: score,
  targetScore: targetScore,
  alreadyUsedThisLevel: alreadyUsedThisLevel,
  coins: coins,
);

void main() {
  group('chào đúng lúc', () {
    test('thua sát nút, đủ xu -> chào', () {
      expect(_offer(score: 95, targetScore: 100), isTrue);
    });

    test('đúng ngưỡng 70% -> chào', () {
      expect(_offer(score: 70, targetScore: 100), isTrue);
    });

    test('dưới ngưỡng -> KHÔNG chào', () {
      expect(
        _offer(score: 69, targetScore: 100),
        isFalse,
        reason: 'thua xa thì mua thêm ô cũng không cứu được, chào chỉ gây bực',
      );
    });

    test('điểm 0 -> không chào', () {
      expect(_offer(score: 0, targetScore: 288), isFalse);
    });
  });

  group('không chào khi không nên', () {
    test('đã thắng (>=1 sao) -> không chào', () {
      for (final s in [1, 2, 3]) {
        expect(_offer(starsEarned: s), isFalse, reason: 'thắng $s sao');
      }
    });

    test('đã dùng trong màn này -> không chào lần hai', () {
      expect(
        _offer(alreadyUsedThisLevel: true),
        isFalse,
        reason: 'tối đa 1 lần/màn, nếu không thì mua tới khi thắng',
      );
    });

    test('side-mode -> KHÔNG chào', () {
      expect(
        _offer(isCampaign: false),
        isFalse,
        reason:
            'mode dùng best-score mà mua được lượt thì kỷ lục nào cũng mua '
            'được',
      );
    });

    test('bàn không có target (puzzle lab) -> không chào', () {
      expect(_offer(score: 500, targetScore: 0), isFalse);
    });

    test('không đủ xu -> không chào (nhưng xem nhóm dưới)', () {
      expect(_offer(coins: kSecondChanceCost - 1), isFalse);
    });

    test('đủ đúng giá -> chào', () {
      expect(_offer(coins: kSecondChanceCost), isTrue);
    });
  });

  group('không đủ xu: hiện nút mờ thay vì im lặng', () {
    test('đủ gần target nhưng thiếu xu -> báo là thiếu xu', () {
      expect(_unaffordable(score: 90, targetScore: 100, coins: 0), isTrue);
    });

    test('đủ xu -> không phải trạng thái thiếu xu', () {
      expect(_unaffordable(coins: kSecondChanceCost), isFalse);
    });

    test('thua quá xa -> không báo thiếu xu (vốn không được chào)', () {
      expect(
        _unaffordable(score: 10, targetScore: 100, coins: 0),
        isFalse,
        reason: 'không đủ điều kiện thì không hiện nút, kể cả nút mờ',
      );
    });

    test('side-mode -> không bao giờ báo thiếu xu', () {
      expect(_unaffordable(isCampaign: false), isFalse);
    });

    test('hai vị từ loại trừ nhau', () {
      for (final coins in [0, kSecondChanceCost - 1, kSecondChanceCost, 9999]) {
        final offer = _offer(coins: coins);
        final poor = _unaffordable(coins: coins);
        expect(
          offer && poor,
          isFalse,
          reason: 'với coins=$coins cả hai cùng true là mâu thuẫn',
        );
      }
    });
  });
}
