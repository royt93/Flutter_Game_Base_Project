import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/object_pool_benchmark.dart';

void main() {
  group('runPooled/runUnpooled: unit', () {
    test(
      'unpooled luôn allocate đúng frames * spawnPerFrame, không tái sử dụng',
      () {
        final result = runUnpooled(
          frames: 50,
          spawnPerFrame: 10,
          lifetimeFrames: 5,
        );

        expect(result.totalAllocations, 50 * 10);
      },
    );

    test(
      'pooled: totalAllocations bị chặn gần capacity, KHÔNG tăng tuyến tính theo frames',
      () {
        final small = runPooled(
          frames: 50,
          spawnPerFrame: 10,
          lifetimeFrames: 5,
          capacity: 100,
        );
        final large = runPooled(
          frames: 500,
          spawnPerFrame: 10,
          lifetimeFrames: 5,
          capacity: 100,
        );

        // Chạy 10x số frame nhưng totalAllocations không tăng theo tỉ lệ đó
        // — đúng bằng chứng "tái sử dụng", không phải "vẫn allocate y hệt".
        expect(large.totalAllocations, lessThan(small.totalAllocations * 10));
        expect(large.totalAllocations, lessThanOrEqualTo(100));
      },
    );

    test(
      'pooled allocate ít hơn hẳn unpooled khi capacity đủ chứa working set '
      '(spawnPerFrame * lifetimeFrames) — kịch bản đại diện đúng cách dùng',
      () {
        const frames = 600;
        const spawnPerFrame = 10;
        const lifetimeFrames = 15; // working set = 150, dưới capacity

        final pooled = runPooled(
          frames: frames,
          spawnPerFrame: spawnPerFrame,
          lifetimeFrames: lifetimeFrames,
          capacity: 200,
        );
        final unpooled = runUnpooled(
          frames: frames,
          spawnPerFrame: spawnPerFrame,
          lifetimeFrames: lifetimeFrames,
        );

        expect(unpooled.totalAllocations, frames * spawnPerFrame);
        // Sau warm-up (~lifetimeFrames đầu), pool chỉ tạo thêm object khi
        // thật sự cần — tổng allocation dừng lại gần working set, không
        // tăng tuyến tính theo frames như unpooled.
        expect(
          pooled.totalAllocations,
          lessThan(unpooled.totalAllocations ~/ 10),
        );
      },
    );

    test('capacity NHỎ HƠN working set (spawnPerFrame * lifetimeFrames): '
        'không tái sử dụng được — đúng hành vi ObjectPool, không phải bug', () {
      const frames = 600;
      const spawnPerFrame = 20;
      const lifetimeFrames = 30; // working set = 600

      final pooled = runPooled(
        frames: frames,
        spawnPerFrame: spawnPerFrame,
        lifetimeFrames: lifetimeFrames,
        capacity: 200, // < working set 600
      );
      final unpooled = runUnpooled(
        frames: frames,
        spawnPerFrame: spawnPerFrame,
        lifetimeFrames: lifetimeFrames,
      );

      // Capacity đếm cả free lẫn active — khi số particle đang sống đồng
      // thời đã vượt capacity, mọi release() đều rơi vào nhánh dispose
      // thay vì giữ lại, nên pool không có gì để tái sử dụng và khớp
      // đúng y hệt unpooled. Test này khoá lại hành vi đó để tránh
      // tưởng nhầm là bug nếu ai đó chọn capacity quá nhỏ.
      expect(pooled.totalAllocations, unpooled.totalAllocations);
    });

    test('capacity <= 0: ObjectPool tự validate, throw AssertionError', () {
      expect(
        () => runPooled(
          frames: 1,
          spawnPerFrame: 1,
          lifetimeFrames: 1,
          capacity: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('CLI: chạy độc lập qua dart run (không cần Flutter runtime)', () {
    test(
      'dart run tool/object_pool_benchmark.dart in đúng kết quả, exit code 0',
      () async {
        final result = await Process.run('dart', [
          'run',
          'tool/object_pool_benchmark.dart',
          '--frames=100',
          '--spawnPerFrame=10',
          '--lifetimeFrames=10',
          '--capacity=150', // > working set (10*10=100): benefit thật sự hiện ra
        ]);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final output = result.stdout as String;
        expect(output, contains('pooled:'));
        expect(output, contains('unpooled:'));
        expect(output, contains('allocationReductionPercent:'));
        expect(output, contains('unpooled: allocations=1000')); // 100*10
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
