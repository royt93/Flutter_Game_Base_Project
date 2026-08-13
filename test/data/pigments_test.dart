import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/achievements.dart';
import 'package:pop_star_blast/data/pigments.dart';

/// T3 — `Pigment` có một `assert` rằng free / mua-bằng-xu / mở-bằng-achievement
/// là **loại trừ nhau**. `assert` chỉ chạy ở debug, nên nó không bảo vệ được
/// bản release; test này mới là thứ giữ invariant đó.
void main() {
  group('bảng kPigments', () {
    test('không rỗng và id không trùng', () {
      expect(kPigments, isNotEmpty);
      final ids = kPigments.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id trùng: $ids');
    });

    test('phần tử đầu là pigment free — code giả định điều này', () {
      // `GameController._load()` luôn `..add(kPigments.first.id)` vào tập đã
      // mở khoá; nếu phần tử đầu không free thì người chơi được tặng không
      // một pigment lẽ ra phải mua.
      expect(kPigments.first.isFree, isTrue);
    });

    test('mỗi pigment thuộc ĐÚNG 1 trong 4 dạng mở khoá', () {
      // [[F19]] thêm dạng thứ tư: `fusionOnly` (chỉ pha ra được). Bản cũ liệt
      // kê 3 dạng và sẽ đỏ ngay khi có pigment fusion — đúng như AC yêu cầu
      // ("đừng để assert nói dối"), nên cập nhật ở đây thay vì nới lỏng.
      for (final p in kPigments) {
        final forms = [
          p.isFree,
          p.coinPrice != null,
          p.unlockAchievementId != null,
          p.fusionOnly,
        ].where((v) => v).length;
        expect(
          forms,
          1,
          reason:
              'pigment "${p.id}" thoả $forms dạng mở khoá — phải đúng 1 '
              '(free / coinPrice / unlockAchievementId / fusionOnly)',
        );
      }
    });

    test('không pigment nào vừa có giá vừa gắn achievement', () {
      for (final p in kPigments) {
        expect(
          p.coinPrice != null && p.unlockAchievementId != null,
          isFalse,
          reason: 'pigment "${p.id}" vi phạm assert của constructor',
        );
      }
    });

    test('giá coin luôn dương', () {
      for (final p in kPigments.where((p) => p.coinPrice != null)) {
        expect(p.coinPrice, greaterThan(0), reason: 'pigment "${p.id}"');
      }
    });

    test('mọi unlockAchievementId trỏ tới achievement CÓ THẬT', () {
      final validIds = kAchievements.map((a) => a.id).toSet();
      for (final p in kPigments.where((p) => p.unlockAchievementId != null)) {
        expect(
          validIds,
          contains(p.unlockAchievementId),
          reason:
              'pigment "${p.id}" gắn achievement "${p.unlockAchievementId}" '
              'không tồn tại → không bao giờ mở khoá được',
        );
      }
    });

    test('nameKey không rỗng và không trùng', () {
      final keys = kPigments.map((p) => p.nameKey).toList();
      expect(keys.every((k) => k.isNotEmpty), isTrue);
      expect(keys.toSet().length, keys.length, reason: 'nameKey trùng: $keys');
    });

    test('có ít nhất 1 pigment mỗi dạng — bảng không thoái hoá', () {
      expect(kPigments.where((p) => p.isFree), isNotEmpty);
      expect(kPigments.where((p) => p.coinPrice != null), isNotEmpty);
      expect(kPigments.where((p) => p.unlockAchievementId != null), isNotEmpty);
    });
  });

  group('encode/decode gemColorOverrides', () {
    test('round-trip giữ nguyên map', () {
      final map = {0: 'coral', 3: 'mint'};
      expect(decodeGemColorOverrides(encodeGemColorOverrides(map)), map);
    });

    test('map rỗng round-trip thành rỗng', () {
      expect(decodeGemColorOverrides(encodeGemColorOverrides({})), isEmpty);
    });

    test('null / chuỗi rỗng → map rỗng, không throw', () {
      expect(decodeGemColorOverrides(null), isEmpty);
      expect(decodeGemColorOverrides(''), isEmpty);
    });

    test('entry hỏng bị bỏ qua, entry hợp lệ vẫn giữ', () {
      expect(decodeGemColorOverrides('0:coral,rác,,2:mint,x:y:z'), {
        0: 'coral',
        2: 'mint',
      });
    });

    test('slot âm bị bỏ qua', () {
      expect(decodeGemColorOverrides('-1:coral,0:mint'), {0: 'mint'});
    });

    test('encode sắp xếp theo slot — chuỗi lưu ổn định', () {
      expect(
        encodeGemColorOverrides({3: 'mint', 0: 'coral'}),
        encodeGemColorOverrides({0: 'coral', 3: 'mint'}),
      );
    });
  });
}
