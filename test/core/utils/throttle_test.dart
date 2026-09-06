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
}
