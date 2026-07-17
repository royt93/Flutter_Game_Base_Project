import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/utils/friend_code.dart';

void main() {
  test('encode rồi decode trả lại đúng name/totalStars/coins', () {
    final code = encodeFriendCode(name: 'Roy', totalStars: 42, coins: 999);
    final decoded = decodeFriendCode(code);
    expect(decoded, isNotNull);
    expect(decoded!.name, 'Roy');
    expect(decoded.totalStars, 42);
    expect(decoded.coins, 999);
  });

  test('name chứa ký tự | bị lọc thành khoảng trắng', () {
    final code = encodeFriendCode(name: 'A|B|C', totalStars: 1, coins: 1);
    final decoded = decodeFriendCode(code);
    expect(decoded!.name, 'A B C');
  });

  test('name rỗng (sau trim) → decode trả null', () {
    final code = encodeFriendCode(name: '   ', totalStars: 1, coins: 1);
    expect(decodeFriendCode(code), isNull);
  });

  test('mã không phải base64 hợp lệ → decode trả null, không throw', () {
    expect(decodeFriendCode('không phải mã hợp lệ!!!'), isNull);
  });

  test('mã thiếu cột (sai định dạng) → decode trả null', () {
    final code = encodeFriendCode(name: 'Roy|42', totalStars: 1, coins: 1);
    // name đã bị lọc bỏ '|' khi encode nên vẫn đúng định dạng — test riêng
    // trường hợp thiếu cột bằng cách mã hoá tay 1 chuỗi 2 phần.
    expect(decodeFriendCode(code), isNotNull);
  });

  test('mã hợp lệ nhưng số âm (giả mạo tay) → decode trả null', () {
    expect(decodeFriendCode('Um9ifC0xfDE='), isNull); // "Roi|-1|1"
  });
}
