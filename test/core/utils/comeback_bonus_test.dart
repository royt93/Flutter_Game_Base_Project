import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/utils/comeback_bonus.dart';

void main() {
  test('chưa từng mở (lastOpenEpochDay = -1) → false', () {
    expect(
      needsComebackBonus(lastOpenEpochDay: -1, todayEpochDay: 100),
      isFalse,
    );
  });

  test('vắng đúng 3 ngày → true', () {
    expect(
      needsComebackBonus(lastOpenEpochDay: 97, todayEpochDay: 100),
      isTrue,
    );
  });

  test('vắng nhiều hơn 3 ngày → true', () {
    expect(
      needsComebackBonus(lastOpenEpochDay: 50, todayEpochDay: 100),
      isTrue,
    );
  });

  test('vắng dưới 3 ngày → false', () {
    expect(
      needsComebackBonus(lastOpenEpochDay: 98, todayEpochDay: 100),
      isFalse,
    );
  });

  test('mở lại cùng ngày → false', () {
    expect(
      needsComebackBonus(lastOpenEpochDay: 100, todayEpochDay: 100),
      isFalse,
    );
  });
}
