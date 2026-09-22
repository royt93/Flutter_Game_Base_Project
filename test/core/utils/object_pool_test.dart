import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/object_pool.dart';

class _Particle {
  _Particle(this.id);
  final int id;
  int x = 0;
  int y = 0;
  bool disposed = false;
}

/// Overrides `==`/`hashCode` by [id] — same shape as a Flame `Vector2` or
/// any value-equality object the class doc explicitly calls out as a case
/// [ObjectPool] must not confuse (BUG-53).
class _ValueEqualParticle {
  _ValueEqualParticle(this.id);
  final int id;

  @override
  bool operator ==(Object other) =>
      other is _ValueEqualParticle && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  group('ObjectPool: acquire/release cơ bản', () {
    test('acquire khi pool rỗng: gọi create() tạo mới', () {
      var createCount = 0;
      final pool = ObjectPool<_Particle>(
        create: () {
          createCount++;
          return _Particle(createCount);
        },
      );

      final p = pool.acquire();

      expect(p.id, 1);
      expect(createCount, 1);
      expect(pool.activeCount, 1);
      expect(pool.freeCount, 0);
    });

    test(
      'release rồi acquire lại: tái sử dụng đúng object cũ, không tạo mới',
      () {
        var createCount = 0;
        final pool = ObjectPool<_Particle>(
          create: () {
            createCount++;
            return _Particle(createCount);
          },
        );

        final p1 = pool.acquire();
        pool.release(p1);
        final p2 = pool.acquire();

        expect(identical(p1, p2), isTrue);
        expect(createCount, 1);
      },
    );

    test('reset() được gọi đúng 1 lần mỗi release, xoá mutable state', () {
      final resetCalls = <int>[];
      final pool = ObjectPool<_Particle>(
        create: () => _Particle(1),
        reset: (p) {
          resetCalls.add(p.id);
          p
            ..x = 0
            ..y = 0;
        },
      );

      final p = pool.acquire()
        ..x = 5
        ..y = 9;
      pool.release(p);

      expect(p.x, 0);
      expect(p.y, 0);
      expect(resetCalls, [1]);
    });
  });

  group('ObjectPool: double/foreign release detection', () {
    test(
      'release object đã được release trước đó (double-release): throw StateError',
      () {
        final pool = ObjectPool<_Particle>(create: () => _Particle(1));
        final p = pool.acquire();
        pool.release(p);

        expect(() => pool.release(p), throwsStateError);
      },
    );

    test(
      'release object không thuộc pool này (foreign release): throw StateError',
      () {
        final pool = ObjectPool<_Particle>(create: () => _Particle(1));
        final foreign = _Particle(99);

        expect(() => pool.release(foreign), throwsStateError);
      },
    );
  });

  group(
    // BUG-53: _active phải dùng IDENTITY, không phải equality — 1 T override
    // `==`/`hashCode` theo giá trị (như Flame Vector2) không được phép làm
    // 2 instance active khác nhau bị nhầm là "cùng 1 object" trong pool.
    'BUG-53: identity, không phải equality, quyết định object nào đang active',
    () {
      test(
        'acquire 2 object khác identity nhưng bằng nhau theo == : '
        'activeCount đếm đúng 2, không bị Set gộp theo equality',
        () {
          final pool = ObjectPool<_ValueEqualParticle>(
            create: () => _ValueEqualParticle(1),
          );
          final a = pool.acquire();
          final b = pool.acquire();

          expect(a == b, isTrue, reason: 'value-equal theo thiết kế test');
          expect(identical(a, b), isFalse);
          expect(pool.activeCount, 2);
        },
      );

      test(
        'release 1 trong 2 object value-equal không ảnh hưởng object kia '
        'còn active — cả 2 vẫn release được độc lập, đúng identity',
        () {
          final pool = ObjectPool<_ValueEqualParticle>(
            create: () => _ValueEqualParticle(1),
          );
          final a = pool.acquire();
          final b = pool.acquire();

          pool.release(a);
          expect(
            pool.activeCount,
            1,
            reason: 'release(a) chỉ bỏ đúng a, b vẫn active',
          );

          // b vẫn thật sự active (đúng identity) -> release được, không
          // throw StateError như thể đã bị release rồi.
          expect(() => pool.release(b), returnsNormally);
        },
      );

      test(
        'double-release ĐÚNG CÙNG 1 identity vẫn bị phát hiện dù có object '
        'khác value-equal cũng từng active',
        () {
          final pool = ObjectPool<_ValueEqualParticle>(
            create: () => _ValueEqualParticle(1),
          );
          final a = pool.acquire();
          pool.acquire(); // b: value-equal với a nếu cùng counter mốc, giữ active
          pool.release(a);

          expect(() => pool.release(a), throwsStateError);
        },
      );
    },
  );

  group('ObjectPool: capacity/dispose/prewarm', () {
    test(
      'prewarm(n) tạo sẵn đúng n object vào free list, không vượt maxCapacity',
      () {
        var createCount = 0;
        final pool = ObjectPool<_Particle>(
          create: () {
            createCount++;
            return _Particle(createCount);
          },
          maxCapacity: 3,
        );

        pool.prewarm(5);

        expect(createCount, 3);
        expect(pool.freeCount, 3);
        expect(pool.activeCount, 0);
      },
    );

    test(
      'release khi free+active đã đạt maxCapacity: dispose() object thay vì giữ lại (không leak)',
      () {
        final disposed = <int>[];
        final pool = ObjectPool<_Particle>(
          create: () => _Particle(1),
          dispose: (p) => disposed.add(p.id),
          maxCapacity: 1,
        );

        final a = pool.acquire();
        pool.prewarm(
          1,
        ); // free đã đầy 1 (== maxCapacity), acquire thêm vẫn cho phép
        final b = pool.acquire();

        pool.release(a);
        pool.release(
          b,
        ); // free+active giờ đã đủ maxCapacity từ a, b bị dispose thay vì giữ

        expect(disposed, isNotEmpty);
        expect(pool.freeCount + pool.activeCount, lessThanOrEqualTo(1));
      },
    );

    test('disposeAll(): dispose mọi object free lẫn active, xoá sạch pool', () {
      final disposed = <int>[];
      final pool = ObjectPool<_Particle>(
        create: () => _Particle(1),
        dispose: (p) => disposed.add(p.id),
      );
      pool.prewarm(2);
      pool.acquire(); // tái sử dụng 1 trong 2 object đã prewarm, không tạo thêm

      pool.disposeAll();

      expect(disposed.length, 2);
      expect(pool.freeCount, 0);
      expect(pool.activeCount, 0);
    });

    test(
      'metrics: totalCreated/peakActive phản ánh đúng lịch sử acquire/release',
      () {
        final pool = ObjectPool<_Particle>(create: () => _Particle(1));

        final a = pool.acquire();
        final b = pool.acquire();
        pool.release(a);
        pool.acquire();

        expect(pool.totalCreated, 2);
        expect(pool.peakActive, 2);

        // giữ tham chiếu b để tránh cảnh báo unused_local_variable
        expect(b, isNotNull);
      },
    );
  });

  group(
    'ObjectPool: burst nhiều acquire/release liên tiếp không leak/tạo tràn',
    () {
      test(
        '1000 lần acquire+release liên tiếp với capacity nhỏ: totalCreated bị chặn đúng',
        () {
          final pool = ObjectPool<_Particle>(
            create: () => _Particle(1),
            maxCapacity: 20,
          );

          for (var i = 0; i < 1000; i++) {
            final p = pool.acquire();
            pool.release(p);
          }

          expect(pool.totalCreated, lessThanOrEqualTo(20));
          expect(pool.activeCount, 0);
        },
      );
    },
  );
}
