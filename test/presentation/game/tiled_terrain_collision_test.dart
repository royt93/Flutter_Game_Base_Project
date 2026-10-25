import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';
import 'package:tiled/tiled.dart';

TiledMap _map(String layers) => TileMapParser.parseTmx('''
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="3" height="3" tilewidth="16" tileheight="16" infinite="0">
 <tileset firstgid="1" name="probe" tilewidth="16" tileheight="16" tilecount="2" columns="2">
  <image source="probe.png" width="32" height="16"/>
  <tile id="1"><properties><property name="solid" type="bool" value="true"/></properties></tile>
 </tileset>
 $layers
</map>
''');

void main() {
  test('solid tile property maps to destination tile rectangle', () {
    final map = _map('''
<layer id="1" name="Ground" width="3" height="3" offsetx="2" offsety="4">
 <data encoding="csv">1,2,1,1,1,1,1,1,1</data>
</layer>
''');
    final colliders = readTiledTerrainColliders(
      map,
      destinationTileSize: Vector2(32, 24),
    );
    final solid = colliders.single as TerrainRectangle;
    expect(solid.position, Vector2(36, 6));
    expect(solid.size, Vector2(32, 24));
  });

  test('collision object layer converts rectangle and polygon with offsets', () {
    final map = _map('''
<objectgroup id="1" name="Collision" offsetx="2" offsety="4">
 <object id="1" name="block" x="16" y="32" width="16" height="8"/>
 <object id="2" name="rock" x="0" y="0"><polygon points="0,0 16,0 8,16"/></object>
</objectgroup>
''');
    final colliders = readTiledTerrainColliders(
      map,
      destinationTileSize: Vector2(32, 24),
    );
    final rectangle = colliders[0] as TerrainRectangle;
    expect(rectangle.position, Vector2(36, 54));
    expect(rectangle.size, Vector2(32, 12));
    final polygon = colliders[1] as TerrainPolygon;
    expect(polygon.position, Vector2(4, 6));
    expect(polygon.vertices, [Vector2.zero(), Vector2(32, 0), Vector2(16, 24)]);
  });

  test('rejects rotated and concave collision geometry', () {
    final rotated = _map('''
<objectgroup id="1" name="Collision">
 <object id="1" name="rotated" x="0" y="0" width="16" height="16" rotation="45"/>
</objectgroup>
''');
    expect(
      () => readTiledTerrainColliders(
        rotated,
        destinationTileSize: Vector2.all(16),
      ),
      throwsFormatException,
    );
    final concave = _map('''
<objectgroup id="1" name="Collision">
 <object id="1" name="concave" x="0" y="0"><polygon points="0,0 16,0 8,8 16,16 0,16"/></object>
</objectgroup>
''');
    expect(
      () => readTiledTerrainColliders(
        concave,
        destinationTileSize: Vector2.all(16),
      ),
      throwsFormatException,
    );
  });

  test('tile rectangles and object polygons block overlapping player bounds', () {
    final wall = TerrainRectangle(Vector2(40, 40), Vector2(20, 20));
    expect(
      terrainColliderOverlapsRect(wall, const Rect.fromLTWH(30, 45, 16, 16)),
      isTrue,
    );
    expect(
      terrainColliderOverlapsRect(wall, const Rect.fromLTWH(0, 0, 16, 16)),
      isFalse,
    );

    final polygon = TerrainPolygon(
      Vector2(40, 40),
      [Vector2.zero(), Vector2(20, 0), Vector2(10, 20)],
    );
    expect(
      terrainColliderOverlapsRect(
        polygon,
        const Rect.fromLTWH(47, 45, 8, 8),
      ),
      isTrue,
    );
    expect(
      terrainColliderOverlapsRect(
        polygon,
        const Rect.fromLTWH(0, 0, 8, 8),
      ),
      isFalse,
    );
  });

  test('TerrainCollider toComponent builds Passive hitboxes with matching bounds', () {
    final rectCollider = TerrainRectangle(Vector2(10, 20), Vector2(30, 40));
    final rectComp = rectCollider.toComponent();
    expect(rectComp.position, Vector2(10, 20));
    expect(rectComp.size, Vector2(30, 40));
    expect(rectComp.children.whereType<ShapeHitbox>(), isNotEmpty);

    final polyCollider = TerrainPolygon(
      Vector2.zero(),
      [Vector2.zero(), Vector2(10, 0), Vector2(5, 10)],
    );
    final polyComp = polyCollider.toComponent();
    expect(polyComp.children.whereType<ShapeHitbox>(), isNotEmpty);
  });
}
