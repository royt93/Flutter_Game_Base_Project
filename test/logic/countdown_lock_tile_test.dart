import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/countdown_lock_tile.dart';

void main() {
  group('isCountdownLockId', () {
    test('countdownLockIdBase được nhận diện là countdown lock', () {
      expect(isCountdownLockId(countdownLockIdBase), isTrue);
    });

    test('null, màu thường, obstacle không bị nhận nhầm', () {
      expect(isCountdownLockId(null), isFalse);
      expect(isCountdownLockId(0), isFalse);
      expect(isCountdownLockId(3), isFalse);
      expect(isCountdownLockId(-1), isFalse);
    });

    test('boss tile id (dải <= bossTileIdBase) không bị nhận nhầm', () {
      expect(isCountdownLockId(bossTileIdBase), isFalse);
      expect(isCountdownLockId(bossTileIdBase - 5), isFalse);
    });
  });

  group('tickCountdownLockTiles', () {
    test('giảm đúng 1 mỗi lần gọi, chưa hết thì trả về null', () {
      final countdownRemaining = {countdownLockIdBase: 5};
      final expired = tickCountdownLockTiles(countdownRemaining);
      expect(expired, isNull);
      expect(countdownRemaining[countdownLockIdBase], 4);
    });

    test('còn 1 lượt, giảm về 0 → hết giờ, trả về id, xoá khỏi map', () {
      final countdownRemaining = {countdownLockIdBase: 1};
      final expired = tickCountdownLockTiles(countdownRemaining);
      expect(expired, countdownLockIdBase);
      expect(countdownRemaining.containsKey(countdownLockIdBase), isFalse);
    });

    test('map rỗng thì không làm gì, trả về null, không crash', () {
      final countdownRemaining = <int, int>{};
      final expired = tickCountdownLockTiles(countdownRemaining);
      expect(expired, isNull);
      expect(countdownRemaining, isEmpty);
    });

    test('nhiều id cùng lúc đều giảm đúng, chỉ id về 0 mới bị xoá', () {
      const otherId = countdownLockIdBase - 1;
      final countdownRemaining = {countdownLockIdBase: 1, otherId: 3};
      final expired = tickCountdownLockTiles(countdownRemaining);
      expect(expired, countdownLockIdBase);
      expect(countdownRemaining.containsKey(countdownLockIdBase), isFalse);
      expect(countdownRemaining[otherId], 2);
    });

    test('chỉ mutate map được truyền vào, không đụng state khác', () {
      final countdownRemaining = {countdownLockIdBase: 1};
      final bossHp = {bossTileIdBase: 3};
      tickCountdownLockTiles(countdownRemaining);
      expect(bossHp[bossTileIdBase], 3);
    });
  });
}
