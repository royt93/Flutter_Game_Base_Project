import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/star_pets.dart';

const _oneHourMs = 60 * 60 * 1000;

/// X22: pet ấp từ mốc 0 — tương đương pet "đã tồn tại từ trước" trong mọi
/// phép tính dưới đây, để các case cũ giữ nguyên ý nghĩa sau khi
/// [idleRewardCoins] đổi từ `petCount` sang danh sách pet.
List<PetInstance> _oldPets(int count) => List.generate(
  count,
  (_) => const PetInstance(typeId: 'ember', hatchedAtMs: 0),
);

void main() {
  group('idleRewardCoins', () {
    test('trả 0 khi không có pet', () {
      expect(idleRewardCoins(lastCollectMs: 0, nowMs: _oneHourMs, pets: []), 0);
    });

    test('trả 0 khi đồng hồ máy lùi (nowMs <= lastCollectMs)', () {
      expect(
        idleRewardCoins(lastCollectMs: 5000, nowMs: 1000, pets: _oldPets(2)),
        0,
      );
      expect(
        idleRewardCoins(lastCollectMs: 5000, nowMs: 5000, pets: _oldPets(2)),
        0,
      );
    });

    test('tính đúng theo số giờ trôi qua và số pet', () {
      final reward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: _oneHourMs,
        pets: _oldPets(2),
      );
      expect(reward, idlePetCoinsPerHour * 2);
    });

    test('áp trần thời gian, không cộng dồn vô hạn', () {
      final cappedReward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: idlePetRewardCapMs,
        pets: _oldPets(1),
      );
      final overCapReward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: idlePetRewardCapMs + 100 * _oneHourMs,
        pets: _oldPets(1),
      );
      expect(overCapReward, cappedReward);
    });

    // X22: hai case dưới là chính lỗ đã đóng — bản cũ nhân `petCount` với toàn
    // bộ khoảng `nowMs - lastCollectMs` và không đọc `hatchedAtMs`.
    test('pet vừa ấp KHÔNG được thưởng cho thời gian trước khi nó tồn tại', () {
      // Tài khoản chưa từng collect: lastCollectMs = 0 (mốc 1970). Ấp pet ở
      // thời điểm `now` rồi hốt ngay — bản cũ trả trọn trần 10 giờ.
      const now = 500 * _oneHourMs;
      final reward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: now,
        pets: const [PetInstance(typeId: 'ember', hatchedAtMs: now)],
      );
      expect(reward, 0);
    });

    test('pet mới ấp không ăn ké thời gian chờ của pet cũ', () {
      // Pet cũ đã chờ quá trần; pet mới ấp đúng 1 giờ trước khi hốt.
      const now = 20 * _oneHourMs;
      final reward = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: now,
        pets: const [
          PetInstance(typeId: 'ember', hatchedAtMs: 0),
          PetInstance(typeId: 'ember', hatchedAtMs: now - _oneHourMs),
        ],
      );
      // Pet cũ: chạm trần 10h. Pet mới: đúng 1h.
      final expected =
          ((idlePetRewardCapMs + _oneHourMs) / _oneHourMs * idlePetCoinsPerHour)
              .floor();
      expect(reward, expected);
    });

    test('trần áp cho từng pet, không phải cho tổng', () {
      const now = 100 * _oneHourMs;
      final one = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: now,
        pets: _oldPets(1),
      );
      final three = idleRewardCoins(
        lastCollectMs: 0,
        nowMs: now,
        pets: _oldPets(3),
      );
      expect(three, one * 3);
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
