import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/game_event_bus.dart';

class _TestEventA extends GameEvent {
  const _TestEventA(this.value);
  final int value;
}

class _TestEventB extends GameEvent {
  const _TestEventB(this.label);
  final String label;
}

void main() {
  test('subscribe(T) chỉ nhận đúng loại event, bỏ qua loại khác', () async {
    final bus = GameEventBus();
    final receivedA = <int>[];
    final receivedB = <String>[];

    bus.subscribe<_TestEventA>((e) => receivedA.add(e.value));
    bus.subscribe<_TestEventB>((e) => receivedB.add(e.label));

    bus.emit(const _TestEventA(1));
    bus.emit(const _TestEventB('x'));
    bus.emit(const _TestEventA(2));
    await Future<void>.delayed(Duration.zero);

    expect(receivedA, [1, 2]);
    expect(receivedB, ['x']);
    await bus.dispose();
  });

  test('thêm 1 loại GameEvent mới không cần sửa bus (mở rộng được)', () async {
    final bus = GameEventBus();
    final received = <String>[];
    bus.subscribe<_TestEventB>((e) => received.add(e.label));

    bus.emit(const _TestEventB('extended'));
    await Future<void>.delayed(Duration.zero);

    expect(received, ['extended']);
    await bus.dispose();
  });

  test('nhiều subscriber cùng 1 loại event đều nhận được, độc lập nhau', () async {
    final bus = GameEventBus();
    final first = <int>[];
    final second = <int>[];
    bus.subscribe<_TestEventA>((e) => first.add(e.value));
    bus.subscribe<_TestEventA>((e) => second.add(e.value));

    bus.emit(const _TestEventA(7));
    await Future<void>.delayed(Duration.zero);

    expect(first, [7]);
    expect(second, [7]);
    await bus.dispose();
  });

  test(
    'subscriber throw exception -> bị bắt qua onError, KHÔNG làm mất event '
    'ở subscriber khác cùng loại, bus vẫn hoạt động bình thường sau đó',
    () async {
      final bus = GameEventBus();
      final errors = <Object>[];
      final okReceived = <int>[];

      bus.subscribe<_TestEventA>((e) {
        throw StateError('boom for ${e.value}');
      }, onError: (error, stack) => errors.add(error));
      bus.subscribe<_TestEventA>((e) => okReceived.add(e.value));

      bus.emit(const _TestEventA(1));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(okReceived, [1]);

      // Bus vẫn hoạt động bình thường cho lần emit tiếp theo — không "chết"
      // sau khi 1 subscriber throw.
      bus.emit(const _TestEventA(2));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(2));
      expect(okReceived, [1, 2]);
      await bus.dispose();
    },
  );

  test(
    'subscriber throw mà không truyền onError -> không rethrow, không crash',
    () async {
      final bus = GameEventBus();
      bus.subscribe<_TestEventA>((e) => throw StateError('no handler'));

      expect(() => bus.emit(const _TestEventA(1)), returnsNormally);
      await Future<void>.delayed(Duration.zero);
      await bus.dispose();
    },
  );

  test('dispose() đóng stream, emit sau dispose không throw', () async {
    final bus = GameEventBus();
    bus.subscribe<_TestEventA>((_) {});

    await bus.dispose();

    expect(() => bus.emit(const _TestEventA(1)), returnsNormally);
  });
}
