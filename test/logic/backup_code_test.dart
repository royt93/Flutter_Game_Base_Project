import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/backup_code.dart';

void main() {
  group('encodeBackupCode / decodeBackupCode', () {
    final data = <String, Object>{
      'coins': 1234,
      'colorblind_mode': true,
      'bgm_volume': 0.4,
      'player_name': 'Roy',
    };

    test('round-trip AES-GCM không cần user input', () async {
      final code = await encodeBackupCode(data);
      expect(code, startsWith(backupCodePrefix));
      expect(
        code.split('.')[0],
        '$backupCodePrefix$backupCodeVersion',
      );
      expect(code, isNot(contains('1234')));
      expect(await decodeBackupCode(code), data);
    });

    test('mỗi lần export sinh nonce khác nhau', () async {
      final first = await encodeBackupCode(data);
      final second = await encodeBackupCode(data);
      expect(second, isNot(first));
    });

    test('dữ liệu bị sửa → null', () async {
      final code = await encodeBackupCode(data);
      final parts = code.split('.');
      parts[3] = '${parts[3]}A';
      expect(await decodeBackupCode(parts.join('.')), isNull);
    });

    test('sai prefix/version/segment → null', () async {
      final code = await encodeBackupCode(data);
      final parts = code.split('.');
      expect(
        await decodeBackupCode(code.replaceFirst('BK2:', 'BK3:')),
        isNull,
      );
      expect(
        await decodeBackupCode('BK2:1.13.${parts.sublist(2).join('.')}'),
        isNull,
      );
      expect(
        await decodeBackupCode('BK2:1.12.${parts[2]}.${parts[3]}'),
        isNull,
      );
    });

    test('payload rỗng, Unicode và map lớn vẫn round-trip', () async {
      final large = <String, Object>{
        '': '',
        'emoji': '🌟 tiếng Việt 日本語',
        for (var i = 0; i < 100; i++) 'key_$i': i,
      };
      expect(
        await decodeBackupCode(await encodeBackupCode({})),
        {},
      );
      expect(
        await decodeBackupCode(await encodeBackupCode(large)),
        large,
      );
    });

    test('BK2 unversioned từ bản cũ vẫn decode được', () async {
      final current = await encodeBackupCode(data);
      final parts = current.split('.');
      final oldFormat = 'BK2:${parts[1]}.${parts[2]}.${parts[3]}.${parts[4]}';
      expect(await decodeBackupCode(oldFormat), data);
    });
  });
}
