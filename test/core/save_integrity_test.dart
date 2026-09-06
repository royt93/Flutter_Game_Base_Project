import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';

void main() {
  group('save_integrity', () {
    const secret = 'my-app-secret';
    final data = <String, Object?>{
      'coins': 100,
      'locale_code': 'en',
      'audio_muted': false,
    };

    test('signExport rồi verifyAndStrip trả về đúng data gốc', () {
      final signed = signExport(data, secret);
      final restored = verifyAndStrip(signed, secret);

      expect(restored, equals(data));
      expect(restored.containsKey('_checksum'), isFalse);
    });

    test('sửa một giá trị sau khi ký khiến verifyAndStrip ném lỗi', () {
      final signed = signExport(data, secret);
      final tampered = Map<String, Object?>.from(signed);
      tampered['coins'] = 999999;

      expect(
        () => verifyAndStrip(tampered, secret),
        throwsA(isA<FormatException>()),
      );
    });

    test('thiếu _checksum khiến verifyAndStrip ném lỗi', () {
      expect(
        () => verifyAndStrip(Map<String, Object?>.from(data), secret),
        throwsA(isA<FormatException>()),
      );
    });

    test('cùng data, hai secret khác nhau cho ra checksum khác nhau', () {
      final signedA = signExport(data, 'secret-a');
      final signedB = signExport(data, 'secret-b');

      expect(signedA['_checksum'], isNot(equals(signedB['_checksum'])));
    });

    test('cùng data, cùng secret, ký hai lần cho checksum giống hệt nhau', () {
      final map1 = <String, Object?>{'b': 2, 'a': 1, 'c': 3};
      final map2 = <String, Object?>{'c': 3, 'a': 1, 'b': 2};

      final signed1 = signExport(map1, secret);
      final signed2 = signExport(map2, secret);

      expect(signed1['_checksum'], equals(signed2['_checksum']));
    });
  });
}
