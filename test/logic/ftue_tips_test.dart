import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/ftue_tips.dart';

/// I85 — luật "khi nào hiện mẩu hướng dẫn".
///
/// Rủi ro lớn nhất của tính năng này không phải hiện sai chỗ mà là **hiện quá
/// nhiều**: 6 popup liên tiếp còn tệ hơn 0 popup. Nên test bám chặt vào các
/// điều kiện tắt.
void main() {
  group('nhóm càng lớn điểm càng cao', () {
    test('campaign level 1, chưa xem -> hiện', () {
      expect(
        shouldShowBiggerGroupsTip(
          isCampaign: true,
          levelId: 1,
          alreadySeen: false,
          skipAllTips: false,
        ),
        isTrue,
      );
    });

    test('đã xem rồi -> không hiện lại', () {
      expect(
        shouldShowBiggerGroupsTip(
          isCampaign: true,
          levelId: 1,
          alreadySeen: true,
          skipAllTips: false,
        ),
        isFalse,
      );
    });

    test('level 2 trở đi -> không hiện', () {
      expect(
        shouldShowBiggerGroupsTip(
          isCampaign: true,
          levelId: 2,
          alreadySeen: false,
          skipAllTips: false,
        ),
        isFalse,
      );
    });

    test('side-mode -> không hiện dù level id nhỏ', () {
      expect(
        shouldShowBiggerGroupsTip(
          isCampaign: false,
          levelId: 1,
          alreadySeen: false,
          skipAllTips: false,
        ),
        isFalse,
      );
    });

    test('công tắc bỏ qua hướng dẫn thắng mọi điều kiện khác', () {
      expect(
        shouldShowBiggerGroupsTip(
          isCampaign: true,
          levelId: 1,
          alreadySeen: false,
          skipAllTips: true,
        ),
        isFalse,
      );
    });
  });

  group('bàn không refill', () {
    test('campaign thua (0 sao), chưa xem -> hiện', () {
      expect(
        shouldShowNoRefillTip(
          isCampaign: true,
          starsEarned: 0,
          alreadySeen: false,
          skipAllTips: false,
        ),
        isTrue,
      );
    });

    test('thắng (>=1 sao) -> không hiện', () {
      for (final stars in [1, 2, 3]) {
        expect(
          shouldShowNoRefillTip(
            isCampaign: true,
            starsEarned: stars,
            alreadySeen: false,
            skipAllTips: false,
          ),
          isFalse,
          reason: 'thắng $stars sao mà vẫn dạy "bàn không refill" là lạc đề',
        );
      }
    });

    test('đã xem rồi -> không hiện lại', () {
      expect(
        shouldShowNoRefillTip(
          isCampaign: true,
          starsEarned: 0,
          alreadySeen: true,
          skipAllTips: false,
        ),
        isFalse,
      );
    });

    test(
      'side-mode -> KHÔNG hiện (Zen có refill, Time Attack thua vì hết giờ)',
      () {
        expect(
          shouldShowNoRefillTip(
            isCampaign: false,
            starsEarned: 0,
            alreadySeen: false,
            skipAllTips: false,
          ),
          isFalse,
          reason:
              'Zen là ngoại lệ duy nhất CÓ refill — nói câu này ở đó là dạy sai '
              'luật; Time Attack thua vì hết giờ, không phải vì cạn ô',
        );
      },
    );

    test('công tắc bỏ qua hướng dẫn thắng mọi điều kiện khác', () {
      expect(
        shouldShowNoRefillTip(
          isCampaign: true,
          starsEarned: 0,
          alreadySeen: false,
          skipAllTips: true,
        ),
        isFalse,
      );
    });
  });

  group('lời khuyên theo mức hụt điểm', () {
    test('sát nút (>=85% target) -> động viên', () {
      expect(
        lossAdviceFor(score: 90, targetScore: 100),
        FtueLossAdvice.soClose,
      );
    });

    test('lưng chừng -> gom nhóm lớn hơn', () {
      expect(
        lossAdviceFor(score: 60, targetScore: 100),
        FtueLossAdvice.biggerGroups,
      );
    });

    test('còn xa -> nhắc tính trước vì bàn hữu hạn', () {
      expect(
        lossAdviceFor(score: 10, targetScore: 100),
        FtueLossAdvice.planAhead,
      );
    });

    test('đúng biên 85% và 50%', () {
      expect(
        lossAdviceFor(score: 85, targetScore: 100),
        FtueLossAdvice.soClose,
      );
      expect(
        lossAdviceFor(score: 50, targetScore: 100),
        FtueLossAdvice.biggerGroups,
      );
    });

    test('target 0 (bàn tự vẽ/side-mode) không chia cho 0', () {
      expect(
        lossAdviceFor(score: 0, targetScore: 0),
        FtueLossAdvice.biggerGroups,
      );
    });

    test('điểm 0 -> luôn là lời khuyên mạnh nhất', () {
      expect(
        lossAdviceFor(score: 0, targetScore: 288),
        FtueLossAdvice.planAhead,
      );
    });
  });
}
