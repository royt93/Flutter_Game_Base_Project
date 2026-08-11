import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/achievements.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';

/// T3 — `kMascotSkins` có 2 invariant mà code ở nơi khác **giả định** nhưng
/// không ai kiểm: phần tử đầu phải free (được tặng mặc định trong
/// `GameController._load()` và dùng làm fallback ở `activeMascotSkin`), và mọi
/// `unlockAchievementId` phải trỏ tới achievement có thật — id sai thì skin
/// không bao giờ mở được và cũng không ai phát hiện.
void main() {
  group('bảng kMascotSkins', () {
    test('không rỗng và id không trùng', () {
      expect(kMascotSkins, isNotEmpty);
      final ids = kMascotSkins.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id trùng: $ids');
    });

    test('phần tử đầu là skin free — nhiều chỗ giả định điều này', () {
      // `GameController`: `storedSkins.add(kMascotSkins.first.id)` (skin free
      // luôn mở khoá) và `orElse: () => kMascotSkins.first` khi id hỏng.
      expect(
        kMascotSkins.first.isFree,
        isTrue,
        reason:
            'nếu phần tử đầu có giá, người chơi được tặng không một skin trả '
            'phí, và fallback khi save hỏng cũng trỏ vào skin chưa mở khoá',
      );
      expect(kMascotSkins.first.id, 'classic');
    });

    test('mỗi skin mở khoá bằng ĐÚNG 1 cách', () {
      for (final s in kMascotSkins) {
        final forms = [
          s.isFree,
          s.coinPrice != null,
          s.unlockAchievementId != null,
        ].where((v) => v).length;
        expect(
          forms,
          1,
          reason: 'skin "${s.id}" thoả $forms dạng mở khoá — phải đúng 1',
        );
      }
    });

    test('không skin nào vừa có giá vừa gắn achievement', () {
      for (final s in kMascotSkins) {
        expect(
          s.coinPrice != null && s.unlockAchievementId != null,
          isFalse,
          reason: 'skin "${s.id}" vi phạm assert của constructor',
        );
      }
    });

    test('mọi unlockAchievementId trỏ tới achievement CÓ THẬT', () {
      final validIds = kAchievements.map((a) => a.id).toSet();
      for (final s in kMascotSkins.where(
        (s) => s.unlockAchievementId != null,
      )) {
        expect(
          validIds,
          contains(s.unlockAchievementId),
          reason:
              'skin "${s.id}" gắn achievement "${s.unlockAchievementId}" '
              'không tồn tại → `_checkAchievements` không bao giờ mở nó',
        );
      }
    });

    test('giá coin luôn dương', () {
      for (final s in kMascotSkins.where((s) => s.coinPrice != null)) {
        expect(s.coinPrice, greaterThan(0), reason: 'skin "${s.id}"');
      }
    });

    test('nameKey không rỗng và không trùng', () {
      final keys = kMascotSkins.map((s) => s.nameKey).toList();
      expect(keys.every((k) => k.isNotEmpty), isTrue);
      expect(keys.toSet().length, keys.length, reason: 'nameKey trùng: $keys');
    });

    test('mỗi skin có palette riêng — không có 2 skin trông giống hệt', () {
      final palettes = kMascotSkins.map((s) => s.palette).toList();
      expect(
        palettes.toSet().length,
        palettes.length,
        reason:
            'hai skin dùng chung palette thì người chơi không phân biệt được',
      );
    });

    test('có đủ cả 3 dạng — bảng không thoái hoá', () {
      expect(kMascotSkins.where((s) => s.isFree), isNotEmpty);
      expect(kMascotSkins.where((s) => s.coinPrice != null), isNotEmpty);
      expect(
        kMascotSkins.where((s) => s.unlockAchievementId != null),
        isNotEmpty,
      );
    });
  });

  group('classicMascotPalette', () {
    test('đúng là palette của skin đầu tiên — 1 nguồn duy nhất', () {
      // `StarMascot` dùng hằng này làm giá trị mặc định; nếu nó lệch khỏi
      // `kMascotSkins.first.palette` thì mascot mặc định và skin "classic"
      // trông khác nhau.
      expect(kMascotSkins.first.palette, classicMascotPalette);
    });
  });
}
