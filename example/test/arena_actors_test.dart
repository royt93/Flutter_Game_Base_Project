import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';
import 'package:roy_casual_kit_example/game/arena_actors.dart';

void main() {
  test('target ignores hits while dead and respawns at exact duration', () {
    var destroyed = 0;
    final target = ArenaTarget(
      position: Vector2(100, 100),
      onDestroyed: (_) => destroyed++,
    );
    for (var i = 0; i < ArenaTarget.maxHp; i++) {
      target.takeHit();
    }
    target.takeHit();
    expect(destroyed, 1);
    expect(target.alive, isFalse);
    target.update(ArenaTarget.respawnSeconds - 0.001);
    expect(target.alive, isFalse);
    target.update(0.001);
    expect(target.alive, isTrue);
    expect(target.hp, ArenaTarget.maxHp);
  });

  test('monster with zero respawn stays dead and reset restores baseline', () {
    var destroyed = 0;
    final monster = ArenaMonster(
      position: Vector2(200, 200),
      chase: () => Vector2(0, 0),
      terrain: const [],
      respawnSeconds: 0,
      onDestroyed: (_) => destroyed++,
    );
    monster.takeHit();
    monster.takeHit();
    monster.takeHit();
    monster.update(100);
    expect(destroyed, 1);
    expect(monster.alive, isFalse);
    monster.reset();
    expect(monster.alive, isTrue);
    expect(monster.hp, ArenaMonster.maxHp);
    expect(monster.position, Vector2(200, 200));
  });

  test('default monster respawns at home after four seconds', () {
    final monster = ArenaMonster(
      position: Vector2(200, 200),
      chase: () => Vector2.zero(),
      terrain: const [],
    );
    monster.takeHit();
    monster.takeHit();
    expect(monster.alive, isFalse);
    monster.update(ArenaMonster.defaultRespawnSeconds - 0.001);
    expect(monster.alive, isFalse);
    monster.update(0.001);
    expect(monster.alive, isTrue);
    expect(monster.position, Vector2(200, 200));
  });

  test(
    'monster contact uses player-center radius and wall blocks knockback',
    () {
      var touches = 0;
      final wall = TerrainRectangle(Vector2(80, 0), Vector2(8, 200));
      final player = Vector2(60, 100);
      final monster = ArenaMonster(
        position: Vector2(70, 100),
        chase: () => player,
        terrain: [wall],
        onTouchPlayer: (_) => touches++,
      );
      monster.update(0.01);
      expect(touches, 1);
      expect(monster.position.x, lessThan(80));
      monster.update(0.01);
      expect(touches, 1);
      monster.update(ArenaMonster.touchCooldownSeconds);
      monster.update(0.01);
      expect(touches, 2);
    },
  );

  test('crate hit is idempotent and leaves collider bounds unchanged', () {
    var broken = 0;
    final crate = ArenaCrate(
      position: Vector2(50, 60),
      onBroken: (_) => broken++,
    );
    crate.takeHit();
    crate.takeHit();
    expect(broken, 1);
    expect(crate.alive, isFalse);
    expect(crate.hitRect, const Rect.fromLTWH(34, 44, 32, 32));
  });
}
