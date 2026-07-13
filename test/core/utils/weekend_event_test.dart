import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/utils/weekend_event.dart';

void main() {
  test('thứ 7 → true', () {
    expect(isWeekendEvent(DateTime(2026, 7, 11)), isTrue); // Sat
  });

  test('chủ nhật → true', () {
    expect(isWeekendEvent(DateTime(2026, 7, 12)), isTrue); // Sun
  });

  test('ngày thường → false', () {
    expect(isWeekendEvent(DateTime(2026, 7, 13)), isFalse); // Mon
  });
}
