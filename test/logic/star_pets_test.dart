import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/star_pets.dart';

void main() {
  group('idleRewardCoins', () {
    test('trả 0 khi không có pet', () {
      expect(idleRewardCoins(lastCollectMs: 0, nowMs: 3600000, petCount: 0), 0);
    });

    test('trả 0 khi đồng hồ máy lùi (nowMs <= lastCollectMs)', () {
      expect(idleRewardCoins(lastCollectMs: 5000, nowMs: 1000, petCount: 2), 0);
      expect(idleRewardCoins(lastCollectMs: 5000, nowMs: 5000, petCount: 2), 0);
    });

    test('tính đúng theo số giờ trôi qua và số pet', () {
      const oneHourMs = 60 * 60 * 1000;
      final reward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: oneHourMs,
        petCount: 2,
      );
      expect(reward, idlePetCoinsPerHour * 2);
    });

    test('áp trần thời gian, không cộng dồn vô hạn', () {
      const oneHourMs = 60 * 60 * 1000;
      final cappedReward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: idlePetRewardCapMs,
        petCount: 1,
      );
      final overCapReward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: idlePetRewardCapMs + 100 * oneHourMs,
        petCount: 1,
      );
      expect(overCapReward, cappedReward);
    });
  });

  group('petTypeById', () {
    test('trả về type đúng theo id', () {
      expect(petTypeById('ember')?.id, 'ember');
    });

    test('trả về null khi id không tồn tại (dữ liệu cũ/hỏng)', () {
      expect(petTypeById('does_not_exist'), isNull);
    });
  });
}
