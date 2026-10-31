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
    expect(monster.hp, monster.maxHp);
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

  test('boss telegraphs then charges and stops at wall; reset restores it', () {
    final player = Vector2(400, 300);
    final boss = ArenaMonster(
      position: Vector2(300, 300),
      chase: () => player,
      terrain: [TerrainRectangle(Vector2(340, 260), Vector2(12, 80))],
      isBoss: true,
      maxHp: ArenaMonster.bossHp,
      speed: ArenaMonster.bossSpeed,
      respawnSeconds: 0,
    );
    expect(boss.hp, 8);
    boss.update(0.01);
    expect(boss.isTelegraphing, isTrue);
    expect(boss.isCharging, isFalse);
    boss.update(ArenaMonster.bossTelegraphSeconds - 0.01);
    expect(boss.isCharging, isFalse);
    boss.update(0.02);
    expect(boss.isCharging, isTrue);
    final before = boss.position.clone();
    boss.update(0.2);
    expect(boss.position.x, greaterThan(before.x));
    expect(boss.position.x, lessThan(340));
    boss.reset();
    expect(boss.hp, ArenaMonster.bossHp);
    expect(boss.isCharging, isFalse);
    expect(boss.isTelegraphing, isFalse);
  });

  test(
    'boss telegraphs then charges and stops at wall; reset restores state',
    () {
      final player = Vector2(400, 300);
      final boss = ArenaMonster(
        position: Vector2(300, 300),
        chase: () => player,
        terrain: [TerrainRectangle(Vector2(340, 260), Vector2(12, 80))],
        isBoss: true,
        maxHp: ArenaMonster.bossHp,
        speed: ArenaMonster.bossSpeed,
        contactDamage: ArenaMonster.bossChargeDamage,
        respawnSeconds: 0,
      );
      expect(boss.hp, ArenaMonster.bossHp);
      boss.update(0.01);
      expect(boss.isTelegraphing, isTrue);
      expect(boss.isCharging, isFalse);
      final telegraphPosition = boss.position.clone();
      boss.update(ArenaMonster.bossTelegraphSeconds - 0.01);
      expect(boss.position, telegraphPosition);
      expect(boss.isCharging, isFalse);
      boss.update(0.02);
      expect(boss.isCharging, isTrue);
      final before = boss.position.clone();
      boss.update(0.2);
      expect(boss.position.x, greaterThan(before.x));
      expect(boss.position.x, lessThan(340));
      boss.reset();
      expect(boss.hp, ArenaMonster.bossHp);
      expect(boss.isCharging, isFalse);
      expect(boss.isTelegraphing, isFalse);
    },
  );

  test('boss charge cannot tunnel through player on a large frame', () {
    var hits = 0;
    final player = Vector2(400, 300);
    final boss = ArenaMonster(
      position: Vector2(300, 300),
      chase: () => player,
      terrain: const [],
      isBoss: true,
      onTouchPlayer: (_) => hits++,
    );
    boss.update(0.01);
    boss.update(ArenaMonster.bossTelegraphSeconds);
    boss.update(0.5);
    expect(hits, 1);
    expect(boss.position.x, lessThan(player.x));
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

  test(
    'dasher telegraphs then dashes fast towards player, stopping at wall',
    () {
      final player = Vector2(400, 300);
      final dasher = ArenaMonster(
        position: Vector2(250, 300),
        chase: () => player,
        terrain: [TerrainRectangle(Vector2(320, 260), Vector2(16, 80))],
        monsterType: ArenaMonsterType.dasher,
      );
      expect(dasher.monsterType, ArenaMonsterType.dasher);
      expect(dasher.hp, 2);

      // Ở cự ly 150 (giữa 60 và 220), dasher kích hoạt telegraph
      dasher.update(0.01);
      expect(dasher.isTelegraphing, isTrue);
      expect(dasher.isCharging, isFalse);

      // Trong 0.4s telegraph, không di chuyển
      final telegraphPos = dasher.position.clone();
      dasher.update(ArenaMonster.dasherTelegraphSeconds - 0.02);
      expect(dasher.position, telegraphPos);

      // Hết 0.4s -> dash!
      dasher.update(0.03);
      expect(dasher.isCharging, isTrue);

      // Di chuyển nhanh nhưng bị chặn bởi tường x = 320
      dasher.update(0.3);
      expect(dasher.position.x, greaterThan(telegraphPos.x));
      expect(dasher.position.x, lessThan(320));
    },
  );

  test('shooter fires projectile toward player at cooldown cadence', () {
    final shots = <(Vector2, Vector2)>[];
    final player = Vector2(400, 300);
    final shooter = ArenaMonster(
      position: Vector2(250, 300),
      chase: () => player,
      terrain: const [],
      monsterType: ArenaMonsterType.shooter,
      onShoot: (at, dir) => shots.add((at, dir)),
    );

    // Ban đầu chưa bắn
    shooter.update(1.0);
    expect(shots, isEmpty);

    // Sau khi hết cooldown 2.2s -> bắn
    shooter.update(1.3);
    expect(shots, hasLength(1));
    expect(shots.first.$1, shooter.position);
    expect(shots.first.$2.x, greaterThan(0)); // Hướng về phía player bên phải
  });

  test('monster bullet damages player and cannot tunnel through obstacle', () {
    var hits = 0;
    var impacts = 0;
    final bullet = ArenaMonsterBullet(
      position: Vector2(100, 100),
      direction: Vector2(1, 0),
      terrain: [TerrainRectangle(Vector2(160, 80), Vector2(20, 40))],
      playerHitRect: () => const Rect.fromLTWH(300, 90, 20, 20),
      onHitPlayer: () => hits++,
      onImpact: (_) => impacts++,
    );

    // Đạn bay chạm tường ở x = 160
    bullet.update(0.5); // 180 * 0.5 = 90 px -> bay từ 100 tới 190
    expect(impacts, 1);
    expect(hits, 0);
  });
}
