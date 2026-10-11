import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/pooled_particle_burst.dart';

void main() {
  group('particle math', () {
    test('radial offset starts at center and ends at travel distance', () {
      const center = Offset(100, 80);
      expect(
        pooledParticleOffsetAt(
          center: center,
          angle: 0,
          travelDistance: 50,
          progress: 0,
        ),
        center,
      );
      final end = pooledParticleOffsetAt(
        center: center,
        angle: 0,
        travelDistance: 50,
        progress: 1,
      );
      expect(end.dx, closeTo(150, 0.001));
      expect(end.dy, 80);
    });

    test('opacity fades only in final 30 percent', () {
      expect(pooledParticleOpacityAt(0.5), 1);
      expect(pooledParticleOpacityAt(0.7), 1);
      expect(pooledParticleOpacityAt(0.85), closeTo(0.5, 0.001));
      expect(pooledParticleOpacityAt(1), 0);
    });
  });

  testWidgets('50 particles return to pool and bursts 2-10 allocate none', (
    tester,
  ) async {
    final key = GlobalKey<PooledParticleBurstState>();
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PooledParticleBurst(
            key: key,
            particleCount: 50,
            duration: const Duration(milliseconds: 400),
            onBurstFinished: () => finished++,
          ),
        ),
      ),
    );
    expect(key.currentState!.totalCreated, 50);
    expect(key.currentState!.freeCount, 50);

    for (var burst = 0; burst < 10; burst++) {
      key.currentState!.burst();
      await tester.pump();
      expect(key.currentState!.activeCount, 50);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(key.currentState!.activeCount, 0);
      expect(key.currentState!.freeCount, 50);
      expect(key.currentState!.totalCreated, 50);
    }
    expect(finished, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion skips allocation and completes immediately', (
    tester,
  ) async {
    final key = GlobalKey<PooledParticleBurstState>();
    var finished = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: PooledParticleBurst(
              key: key,
              particleCount: 50,
              onBurstFinished: () => finished++,
            ),
          ),
        ),
      ),
    );
    key.currentState!.burst();
    await tester.pump();
    await tester.pump();
    expect(key.currentState!.activeCount, 0);
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount mid-burst releases all active particles', (
    tester,
  ) async {
    final key = GlobalKey<PooledParticleBurstState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PooledParticleBurst(
            key: key,
            particleCount: 50,
            duration: const Duration(seconds: 1),
          ),
        ),
      ),
    );
    key.currentState!.burst();
    await tester.pump();
    expect(key.currentState!.activeCount, 50);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
