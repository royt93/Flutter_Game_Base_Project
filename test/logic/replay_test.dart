import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/replay.dart';

void main() {
  test('encode rồi decode trả lại đúng levelId/seed/taps', () {
    final data = ReplayData(
      levelId: 5,
      seed: 123456,
      taps: const [(0, 0), (1, 2), (7, 3)],
    );
    final code = encodeReplay(data);
    final decoded = decodeReplay(code);
    expect(decoded, isNotNull);
    expect(decoded!.levelId, 5);
    expect(decoded.seed, 123456);
    expect(decoded.taps, data.taps);
  });

  test('taps rỗng vẫn encode/decode đúng', () {
    final data = ReplayData(levelId: 1, seed: 0, taps: const []);
    final decoded = decodeReplay(encodeReplay(data));
    expect(decoded, isNotNull);
    expect(decoded!.taps, isEmpty);
  });

  test('mã không phải base64 hợp lệ → decode trả null, không throw', () {
    expect(decodeReplay('không phải mã hợp lệ!!!'), isNull);
  });

  test('mã hợp lệ base64 nhưng thiếu cột (chỉ 2 phần) → decode trả null', () {
    // "5|123" → base64url, thiếu phần taps.
    expect(decodeReplay('NXwxMjM='), isNull);
  });

  test('levelId <= 0 (giả mạo tay) → decode trả null', () {
    // "0|1|0,0" → base64url.
    expect(decodeReplay('MHwxfDAsMA=='), isNull);
  });

  test('seed không phải số → decode trả null', () {
    // "1|abc|0,0" → base64url.
    expect(decodeReplay('MXxhYmN8MCww'), isNull);
  });

  test('1 tap sai định dạng (thiếu dấu phẩy) → decode trả null', () {
    // "1|1|00" → base64url.
    expect(decodeReplay('MXwxfDAw'), isNull);
  });

  test('tap có toạ độ âm (giả mạo tay) → decode trả null', () {
    // "1|1|-1,0" → base64url.
    expect(decodeReplay('MXwxfC0xLDA='), isNull);
  });

  test('chuỗi rỗng → decode trả null', () {
    expect(decodeReplay(''), isNull);
  });

  test(
    'cùng seed chạy 2 lần cho cùng chuỗi taps → xác nhận encode ổn định',
    () {
      final data = ReplayData(
        levelId: 200,
        seed: 987654321,
        taps: const [(3, 4), (5, 6)],
      );
      final codeA = encodeReplay(data);
      final codeB = encodeReplay(data);
      expect(codeA, codeB);
    },
  );
}
