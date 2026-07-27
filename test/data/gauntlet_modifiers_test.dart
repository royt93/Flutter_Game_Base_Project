import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/gauntlet_modifiers.dart';

void main() {
  test('cùng epoch-day → cùng modifier (deterministic)', () {
    expect(modifierForDay(100).id, modifierForDay(100).id);
  });

  test('tuần hoàn đều theo % số modifier', () {
    for (var day = 0; day < kGauntletModifiers.length * 3; day++) {
      expect(
        modifierForDay(day).id,
        kGauntletModifiers[day % kGauntletModifiers.length].id,
      );
    }
  });

  test('mọi modifier đều có id/nameKey/descKey khác rỗng và duy nhất', () {
    final ids = kGauntletModifiers.map((m) => m.id).toSet();
    expect(ids.length, kGauntletModifiers.length);
    for (final m in kGauntletModifiers) {
      expect(m.id, isNotEmpty);
      expect(m.nameKey, isNotEmpty);
      expect(m.descKey, isNotEmpty);
    }
  });

  test(
    'đúng đủ 4 modifier: no_undo/short_combo/four_colors/reverse_gravity',
    () {
      final ids = kGauntletModifiers.map((m) => m.id).toSet();
      expect(ids, {'no_undo', 'short_combo', 'four_colors', 'reverse_gravity'});
    },
  );
}
