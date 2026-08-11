import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/backup_code.dart';
import 'package:pop_star_blast/logic/challenge_code.dart';
import 'package:pop_star_blast/logic/puzzle_code.dart';
import 'package:pop_star_blast/logic/replay.dart';

/// X25 — 4 codec dưới đây nhận chuỗi **người chơi dán vào** (mã chia sẻ từ bạn
/// bè, QR, internet). Trước đợt này không codec nào giới hạn kích thước, nên
/// một mã đúng cú pháp nhưng khổng lồ làm treo/OOM UI isolate: `decodeReplay`
/// materialize hàng trăm nghìn tap rồi phát lại từng cái bằng timer,
/// `decodePuzzleGrid` dựng board 250k ô, `senderName` dài vài trăm KB nhét
/// thẳng vào `Text`, và `AesGcm.decrypt` chạy trên payload hàng MB.
///
/// Mỗi test dưới đây kiểm 2 điều: **từ chối** payload quá lớn, và **không phá**
/// mã hợp lệ ngay dưới ngưỡng.
String _b64(String raw) => base64Url.encode(utf8.encode(raw));

/// Đệm số 0 vào đầu một số để kéo dài mã mà **không** làm nó sai cú pháp:
/// `int.tryParse('000...1') == 1`. Cần thiết để test đúng lớp guard độ dài —
/// nếu chỉ dán `'A' * 5000` thì base64 decode ra rác và decoder trả `null`
/// **dù không có guard nào**, tức test xanh mà chẳng chứng minh được gì
/// (phát hiện qua mutation-check).
String _pad(int value, int width) => value.toString().padLeft(width, '0');

void main() {
  group('X25 decodeReplay', () {
    test('mã dài hơn kMaxCodeLength -> null, dù nội dung hợp lệ', () {
      // Hợp lệ hoàn toàn về cú pháp (levelId=1, seed=42, 1 tap) — chỉ dài quá.
      final code = _b64('${_pad(1, kMaxCodeLength * 2)}|42|0,0');
      expect(code.length, greaterThan(kMaxCodeLength));
      expect(decodeReplay(code), isNull);
    });

    test('số tap vượt kMaxReplayTaps -> null', () {
      final taps = List.filled(kMaxReplayTaps + 1, '0,0').join(';');
      expect(decodeReplay(_b64('1|42|$taps')), isNull);
    });

    test('đúng kMaxReplayTaps vẫn decode được (không chặn nhầm mã thật)', () {
      final taps = List.filled(kMaxReplayTaps, '0,0').join(';');
      final decoded = decodeReplay(_b64('1|42|$taps'));
      expect(decoded, isNotNull);
      expect(decoded!.taps.length, kMaxReplayTaps);
    });

    test('replay của 1 ván thật (dưới trăm tap) vẫn round-trip', () {
      final data = ReplayData(
        levelId: 7,
        seed: 12345,
        taps: List.generate(80, (i) => (i % 11, i % 12)),
      );
      final decoded = decodeReplay(encodeReplay(data));
      expect(decoded?.taps.length, 80);
      expect(decoded?.levelId, 7);
    });
  });

  group('X25 decodePuzzleGrid', () {
    test('mã dài hơn kMaxCodeLength -> null, dù nội dung hợp lệ', () {
      final code = _b64('${_pad(1, kMaxCodeLength * 2)}|1|0');
      expect(code.length, greaterThan(kMaxCodeLength));
      expect(decodePuzzleGrid(code), isNull);
    });

    test('board khai báo vượt kMaxPuzzleSide -> null dù mã rất ngắn', () {
      // Đây là case mà cap độ dài chuỗi KHÔNG bắt được: ô trống mã hoá thành
      // chuỗi rỗng, nên board 400x400 = 160k ô chỉ tốn vài trăm KB... và
      // board 30x30 thì chỉ tốn ~1KB, thừa sức lọt cap chuỗi.
      const side = kMaxPuzzleSide + 10;
      final row = List.filled(side, '').join(',');
      final rows = List.filled(side, row).join(';');
      final code = _b64('$side|$side|$rows');
      expect(code.length, lessThan(kMaxCodeLength));
      expect(
        decodePuzzleGrid(code),
        isNull,
        reason: 'cap ngữ nghĩa phải bắt được, cap độ dài chuỗi thì không',
      );
    });

    test('board đúng kMaxPuzzleSide vẫn decode được', () {
      const side = kMaxPuzzleSide;
      final row = List.filled(side, '0').join(',');
      final rows = List.filled(side, row).join(';');
      final decoded = decodePuzzleGrid(_b64('$side|$side|$rows'));
      expect(decoded, isNotNull);
      expect(decoded!.length, side);
    });

    test('board kích thước editor thật (11x12) vẫn round-trip', () {
      final grid = List.generate(
        11,
        (r) => List<int?>.generate(12, (c) => (r + c) % 4),
      );
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded?.length, 11);
      expect(decoded?.first.length, 12);
    });
  });

  group('X25 decodeChallengeCode', () {
    test('mã dài hơn kMaxCodeLength -> null, dù nội dung hợp lệ', () {
      final code =
          '$challengeCodePrefix${_b64('${_pad(5, kMaxCodeLength * 2)}|100|roy')}';
      expect(code.length, greaterThan(kMaxCodeLength));
      expect(decodeChallengeCode(code), isNull);
    });

    test('senderName vượt kMaxSenderNameLength -> null', () {
      final name = 'x' * (kMaxSenderNameLength + 1);
      final code = '$challengeCodePrefix${_b64('5|100|$name')}';
      expect(code.length, lessThan(kMaxCodeLength));
      expect(
        decodeChallengeCode(code),
        isNull,
        reason:
            'senderName là "phần còn lại của chuỗi" nên trước đây không có '
            'giới hạn nào — tên vài trăm KB vẫn decode rồi treo layout',
      );
    });

    test('senderName đúng kMaxSenderNameLength vẫn nhận', () {
      final name = 'x' * kMaxSenderNameLength;
      final decoded = decodeChallengeCode(
        '$challengeCodePrefix${_b64('5|100|$name')}',
      );
      expect(decoded?.senderName, name);
    });

    test('seed code: senderName quá dài -> null', () {
      final name = 'x' * (kMaxSenderNameLength + 1);
      expect(
        decodeChallengeSeedCode(
          '$challengeSeedCodePrefix${_b64('5|99|100|$name')}',
        ),
        isNull,
      );
    });

    test('seed code: mã quá dài -> null, dù nội dung hợp lệ', () {
      final code =
          '$challengeSeedCodePrefix'
          '${_b64('${_pad(5, kMaxCodeLength * 2)}|99|100|roy')}';
      expect(code.length, greaterThan(kMaxCodeLength));
      expect(decodeChallengeSeedCode(code), isNull);
    });
  });

  group('X25 decodeBackupCode', () {
    test(
      'mã dài hơn kMaxBackupCodeLength -> null, dù là mã hợp lệ thật',
      () async {
        // Mã do CHÍNH `encodeBackupCode` sinh ra, giải mã được hoàn
        // toàn — chỉ vượt ngưỡng. Nếu chỉ dán 'A'*N thì `split('.')` hỏng và
        // decoder trả null **dù không có guard**, test sẽ xanh giả.
        final bulky = <String, Object>{
          for (var i = 0; i < 1200; i++) 'key_$i': 'x' * 60,
        };
        final code = await encodeBackupCode(bulky);
        expect(code.length, greaterThan(kMaxBackupCodeLength));
        expect(await decodeBackupCode(code), isNull);
      },
    );

    test(
      'backup của save đầy đủ vẫn round-trip (ngưỡng không quá chặt)',
      () async {
        // ~100 key, mô phỏng profile thật đã chơi nhiều.
        final data = <String, Object>{
          for (var i = 0; i < 100; i++) 'key_$i': i * 1000,
          'player_name': 'người chơi tiếng Việt có dấu',
        };
        final code = await encodeBackupCode(data);
        expect(code.length, lessThan(kMaxBackupCodeLength));
        final decoded = await decodeBackupCode(code);
        expect(decoded?.length, data.length);
        expect(decoded?['key_99'], 99000);
      },
    );
  });
}
