import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit_example/game/arena_actors.dart';

void main() {
  test('pickup expires at eight seconds exactly once', () {
    var expired = 0;
    final pickup = ArenaPickup(
      position: Vector2(40, 60),
      kind: ArenaPickupKind.heal,
      onExpired: () => expired++,
      onCollected: (_) {},
    );

    expect(pickup.hitRect, const Rect.fromLTWH(16, 36, 48, 48));
    pickup.update(7.999);
    expect(expired, 0);
    pickup.update(0.001);
    pickup.update(5);
    expect(expired, 1);
  });

  test('collect removes pickup and cannot invoke collection twice', () {
    final collected = <ArenaPickupKind>[];
    var expired = 0;
    final pickup = ArenaPickup(
      position: Vector2(0, 0),
      kind: ArenaPickupKind.rapidFire,
      onExpired: () => expired++,
      onCollected: collected.add,
    );

    pickup.collect();
    pickup.collect();
    pickup.update(9);
    expect(collected, [ArenaPickupKind.rapidFire]);
    expect(expired, 0);
  });
}
