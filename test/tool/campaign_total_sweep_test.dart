import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';

/// Safeguard thêm sau audit thứ 2 của Round-8 (2026-08-06): khi `kLevelCount`
/// tăng (vd 240 → 260 ở World 13), 2 chỗ prose thực tế đã quên sweep theo và
/// lọt qua `flutter test` xanh vì không phải logic — 1 ở
/// `app_translations.dart` (bắt được lúc làm Item 1), 1 ở
/// `doc/RELEASE_CHECKLIST.md` (lọt lưới, chỉ phát hiện nhờ blind-review lần
/// 2). Test này tự so với `kLevelCount` hiện tại nên không cần cập nhật tay
/// mỗi round — chỉ đỏ khi có chỗ còn nhắc đúng tổng số màn của round LIỀN
/// TRƯỚC (không phải mọi số cũ trong lịch sử, đủ để bắt lỗi "quên sweep 1
/// bước" là dạng lỗi thực tế đã xảy ra 2 lần).
void main() {
  final staleTotal = kLevelCount - 20;

  // X16: cùng dòng prose ở `RELEASE_CHECKLIST.md` còn đếm world và side mode,
  // và cả 2 số đó cũng đã trôi (11 world / 9 side mode trong khi thực tế là
  // 13/14) — cùng một dạng lỗi "quên sweep" mà test này sinh ra để bắt, chỉ
  // khác con số. Suy thẳng từ `kWorlds` và `GameMode` nên không cần cập nhật
  // tay mỗi round.
  test('doc/RELEASE_CHECKLIST.md: số world khớp kWorlds hiện tại', () {
    final content = File('doc/RELEASE_CHECKLIST.md').readAsStringSync();
    expect(
      content.contains('${kWorlds.length} world'),
      isTrue,
      reason:
          'Không thấy "${kWorlds.length} world" trong RELEASE_CHECKLIST.md — '
          'có thể quên sweep sau khi thêm world.',
    );
  });

  test('doc/RELEASE_CHECKLIST.md: số side mode khớp GameMode hiện tại', () {
    // Mọi giá trị `GameMode` trừ `campaign` đều là side mode (xem CLAUDE.md).
    final sideModeCount = GameMode.values.length - 1;
    final content = File('doc/RELEASE_CHECKLIST.md').readAsStringSync();
    expect(
      content.contains('$sideModeCount side mode'),
      isTrue,
      reason:
          'Không thấy "$sideModeCount side mode" trong RELEASE_CHECKLIST.md — '
          'có thể quên sweep sau khi thêm GameMode.',
    );
  });

  test(
    'doc/RELEASE_CHECKLIST.md: tổng số màn campaign khớp kLevelCount hiện tại',
    () {
      final content = File('doc/RELEASE_CHECKLIST.md').readAsStringSync();
      expect(
        content.contains('$kLevelCount màn'),
        isTrue,
        reason:
            'Không thấy "$kLevelCount màn" trong RELEASE_CHECKLIST.md — '
            'có thể quên sweep sau khi kLevelCount đổi.',
      );
      expect(
        content.contains('$staleTotal màn'),
        isFalse,
        reason:
            'RELEASE_CHECKLIST.md vẫn còn nhắc "$staleTotal màn" (số liệu '
            'của round trước) — quên sweep sang $kLevelCount.',
      );
    },
  );

  test(
    'app_translations: không còn locale nào nhắc tổng số màn cũ ($staleTotal)',
    () {
      final keys = AppTranslations().keys;
      final offenders = <String>[];
      for (final locale in keys.entries) {
        for (final entry in locale.value.entries) {
          final v = entry.value;
          if (v.contains('$staleTotal level') ||
              v.contains('$staleTotal màn')) {
            offenders.add('${locale.key}/${entry.key}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Các key sau vẫn nhắc "$staleTotal level(s)/màn" (số liệu cũ, '
            'quên sweep theo kLevelCount=$kLevelCount): $offenders',
      );
    },
  );
}
