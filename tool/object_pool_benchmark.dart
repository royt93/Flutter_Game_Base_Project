// Headless FlameObjectPool benchmark (FEAT-48) — no Flutter/Flame runtime
// dependency. Simulates a representative "particle burst" gameplay loop
// (spawn N particles/frame, despawn ones whose lifetime expired) for a
// fixed number of frames, twice: once reusing instances through the real
// `ObjectPool` this package ships (`core/utils/object_pool.dart`), once
// allocating a fresh instance on every spawn the way an unpooled
// implementation would. Prints each run's total allocation count and
// elapsed wall time, so the pooled version's allocation reduction is
// visible and reproducible.
//
// Calls the SAME `ObjectPool` class the real game code uses (not a
// reimplementation) — see test/tool/object_pool_benchmark_test.dart for
// the cross-check that its allocation counts behave as claimed.
//
// Defaults keep concurrent-alive particles (spawnPerFrame * lifetimeFrames)
// comfortably under capacity — a pool sized SMALLER than the working set
// shows no reuse at all (every release lands past capacity and gets
// disposed, matching the unpooled baseline exactly), which is correct
// ObjectPool behavior but not a useful *demonstration* of pooling's
// benefit. Pick capacity >= spawnPerFrame * lifetimeFrames for a
// representative scenario.
//
// Usage:
//   dart run tool/object_pool_benchmark.dart [--frames=600]
//     [--spawnPerFrame=10] [--lifetimeFrames=15] [--capacity=200]

import 'dart:io';

import 'package:roy_casual_kit/core/utils/object_pool.dart';

class _Particle {
  int framesLeft = 0;
}

/// One benchmark run's outcome — how many [_Particle]s were actually
/// allocated (`create()` calls, for the pooled run; every spawn, for the
/// unpooled one) and how long the loop took.
class BenchmarkResult {
  const BenchmarkResult({required this.totalAllocations, required this.elapsed});

  final int totalAllocations;
  final Duration elapsed;
}

/// Runs the particle-burst scenario through a real [ObjectPool] —
/// [BenchmarkResult.totalAllocations] is [ObjectPool.totalCreated], which
/// stays bounded near [capacity] regardless of [frames] once the pool has
/// warmed up, since expired particles are returned instead of discarded.
BenchmarkResult runPooled({
  required int frames,
  required int spawnPerFrame,
  required int lifetimeFrames,
  required int capacity,
}) {
  final pool = ObjectPool<_Particle>(
    create: () => _Particle(),
    reset: (p) => p.framesLeft = 0,
    maxCapacity: capacity,
  );
  final alive = <_Particle>[];
  final stopwatch = Stopwatch()..start();
  for (var frame = 0; frame < frames; frame++) {
    for (var i = 0; i < spawnPerFrame; i++) {
      alive.add(pool.acquire()..framesLeft = lifetimeFrames);
    }
    alive.removeWhere((p) {
      p.framesLeft--;
      final expired = p.framesLeft <= 0;
      if (expired) pool.release(p);
      return expired;
    });
  }
  stopwatch.stop();
  return BenchmarkResult(
    totalAllocations: pool.totalCreated,
    elapsed: stopwatch.elapsed,
  );
}

/// Runs the same scenario allocating a fresh [_Particle] on every spawn and
/// letting expired ones simply drop out of [alive] — the unpooled
/// baseline. [BenchmarkResult.totalAllocations] is always exactly
/// `frames * spawnPerFrame`.
BenchmarkResult runUnpooled({
  required int frames,
  required int spawnPerFrame,
  required int lifetimeFrames,
}) {
  final alive = <_Particle>[];
  var totalAllocations = 0;
  final stopwatch = Stopwatch()..start();
  for (var frame = 0; frame < frames; frame++) {
    for (var i = 0; i < spawnPerFrame; i++) {
      totalAllocations++;
      alive.add(_Particle()..framesLeft = lifetimeFrames);
    }
    alive.removeWhere((p) {
      p.framesLeft--;
      return p.framesLeft <= 0;
    });
  }
  stopwatch.stop();
  return BenchmarkResult(totalAllocations: totalAllocations, elapsed: stopwatch.elapsed);
}

int _intArg(Map<String, String> options, String key, int fallback) =>
    int.parse(options[key] ?? '$fallback');

void main(List<String> args) {
  final options = <String, String>{
    for (final arg in args)
      if (arg.startsWith('--') && arg.contains('='))
        arg.substring(2).split('=').first: arg.substring(2).split('=').last,
  };

  final frames = _intArg(options, 'frames', 600);
  final spawnPerFrame = _intArg(options, 'spawnPerFrame', 10);
  final lifetimeFrames = _intArg(options, 'lifetimeFrames', 15);
  final capacity = _intArg(options, 'capacity', 200);

  final pooled = runPooled(
    frames: frames,
    spawnPerFrame: spawnPerFrame,
    lifetimeFrames: lifetimeFrames,
    capacity: capacity,
  );
  final unpooled = runUnpooled(
    frames: frames,
    spawnPerFrame: spawnPerFrame,
    lifetimeFrames: lifetimeFrames,
  );

  final reductionPercent = unpooled.totalAllocations == 0
      ? 0.0
      : (1 - pooled.totalAllocations / unpooled.totalAllocations) * 100;

  stdout.writeln(
    'scenario: frames=$frames spawnPerFrame=$spawnPerFrame '
    'lifetimeFrames=$lifetimeFrames capacity=$capacity',
  );
  stdout.writeln(
    'pooled:   allocations=${pooled.totalAllocations} '
    'elapsedUs=${pooled.elapsed.inMicroseconds}',
  );
  stdout.writeln(
    'unpooled: allocations=${unpooled.totalAllocations} '
    'elapsedUs=${unpooled.elapsed.inMicroseconds}',
  );
  stdout.writeln(
    'allocationReductionPercent: ${reductionPercent.toStringAsFixed(1)}',
  );
}
