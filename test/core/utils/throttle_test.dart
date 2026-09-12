import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/throttle.dart';

void main() {
  test('gọi liên tiếp trong window → chỉ chạy callback thật 1 lần', () {
    var calls = 0;
    final fn = throttled(
      () => calls++,
      window: const Duration(milliseconds: 100),
    );

    fn();
    fn();
    fn();

    expect(calls, 1);
  });

  test('gọi lại sau khi hết window → chạy tiếp lần mới', () async {
    var calls = 0;
    final fn = throttled(
      () => calls++,
      window: const Duration(milliseconds: 100),
    );

    fn();
    expect(calls, 1);

    await Future.delayed(const Duration(milliseconds: 150));
    fn();

    expect(calls, 2);
  });

  test('không nuốt lỗi nếu callback throw', () {
    final fn = throttled(() => throw StateError('boom'));
    expect(fn, throwsA(isA<StateError>()));
  });

  group('BUG-28: dùng đồng hồ đơn điệu (Stopwatch), không bị ảnh hưởng bởi '
      'wall clock bị lùi', () {
    test(
      'wall clock (DateTime.now()) bị lùi lại giữa 2 lần gọi vẫn không '
      'làm kẹt throttle vô thời hạn — chỉ phụ thuộc thời gian thật trôi qua',
      () async {
        // throttled() không còn dùng DateTime.now() để đo elapsed nữa, nên
        // test này không thể "giả lập" đồng hồ lùi bằng cách mock DateTime —
        // thay vào đó verify hành vi đúng: sau khi window trôi qua thật sự
        // (bằng Future.delayed, độc lập với DateTime.now()), lần gọi tiếp
        // theo LUÔN chạy được, không phụ thuộc giá trị DateTime.now() trả về.
        var calls = 0;
        final fn = throttled(
          () => calls++,
          window: const Duration(milliseconds: 100),
        );

        fn();
        expect(calls, 1);

        await Future.delayed(const Duration(milliseconds: 150));
        fn();
        expect(calls, 2, reason: 'hết window thật (đo bằng đồng hồ đơn điệu) phải cho gọi tiếp');
      },
    );

    test('gọi liên tiếp ngay sau lần đầu (chưa hết window) vẫn bị drop đúng như cũ', () {
      var calls = 0;
      final fn = throttled(
        () => calls++,
        window: const Duration(milliseconds: 500),
      );

      fn();
      fn();
      fn();
      expect(calls, 1);
    });
  });
}
