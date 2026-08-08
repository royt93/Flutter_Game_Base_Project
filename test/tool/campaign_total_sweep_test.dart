import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/data/levels.dart';

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
