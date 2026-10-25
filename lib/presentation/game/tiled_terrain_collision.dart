import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:tiled/tiled.dart' as tiled;

sealed class TerrainCollider {
  const TerrainCollider();

  PositionComponent toComponent();
}

class TerrainRectangle extends TerrainCollider {
  const TerrainRectangle(this.position, this.size);

  final Vector2 position;
  final Vector2 size;

  @override
  PositionComponent toComponent() =>
      PositionComponent(position: position.clone(), size: size.clone())
        ..add(RectangleHitbox(collisionType: CollisionType.passive));
}

class TerrainPolygon extends TerrainCollider {
  const TerrainPolygon(this.vertices);

  final List<Vector2> vertices;

  @override
  PositionComponent toComponent() =>
      PolygonComponent([for (final v in vertices) v.clone()])
        ..add(PolygonHitbox([
          for (final v in vertices) v.clone(),
        ], collisionType: CollisionType.passive));
}

List<TerrainCollider> readTiledTerrainColliders(
  tiled.TiledMap map, {
  required Vector2 destinationTileSize,
  String collisionLayerName = 'Collision',
  String solidPropertyName = 'solid',
}) {
  final scaleX = destinationTileSize.x / map.tileWidth;
  final scaleY = destinationTileSize.y / map.tileHeight;
  final colliders = <TerrainCollider>[];

  for (final layer in map.layers) {
    if (layer is tiled.TileLayer && layer.tileData != null) {
      for (var y = 0; y < layer.tileData!.length; y++) {
        final row = layer.tileData![y];
        for (var x = 0; x < row.length; x++) {
          final gid = row[x].tile;
          if (gid == 0) continue;
          final tile = map.tileByGid(gid);
          if (tile?.properties.getValue<bool>(solidPropertyName) != true) {
            continue;
          }
          colliders.add(
            TerrainRectangle(
              Vector2(
                (x * map.tileWidth + layer.offsetX) * scaleX,
                (y * map.tileHeight + layer.offsetY) * scaleY,
              ),
              destinationTileSize.clone(),
            ),
          );
        }
      }
    }

    if (layer is tiled.ObjectGroup && layer.name == collisionLayerName) {
      for (final object in layer.objects.where((object) => object.visible)) {
        if (object.rotation != 0) {
          throw FormatException(
            'Rotated Tiled collision objects are unsupported: ${object.name}',
          );
        }
        final x = (object.x + layer.offsetX) * scaleX;
        final y = (object.y + layer.offsetY) * scaleY;
        if (object.isPolygon) {
          if (object.polygon.length < 3) {
            throw FormatException(
              'Tiled collision polygon needs at least 3 points: ${object.name}',
            );
          }
          final vertices = [
            for (final point in object.polygon)
              Vector2(
                point.x * scaleX,
                point.y * scaleY,
              ),
          ];
          _validateSimplePolygon(vertices, object.name);
          colliders.add(TerrainPolygon(vertices));
        } else if (object.isRectangle) {
          if (object.width <= 0 || object.height <= 0) {
            throw FormatException(
              'Tiled collision rectangle needs positive dimensions: ${object.name}',
            );
          }
          colliders.add(
            TerrainRectangle(
              Vector2(x, y),
              Vector2(object.width * scaleX, object.height * scaleY),
            ),
          );
        } else {
          throw FormatException(
            'Unsupported Tiled collision object shape: ${object.name}',
          );
        }
      }
    }
  }
  return colliders;
}

void _validateSimplePolygon(List<Vector2> vertices, String name) {
  final crosses = <double>[];
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i];
    final b = vertices[(i + 1) % vertices.length];
    final c = vertices[(i + 2) % vertices.length];
    crosses.add((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x));
  }
  if (crosses.any((cross) => cross.abs() < 1e-9) ||
      (crosses.any((cross) => cross > 0) && crosses.any((cross) => cross < 0))) {
    throw FormatException('Tiled collision polygon must be simple and convex: $name');
  }
  final signedArea = vertices.fold<double>(0, (area, a) {
    final b = vertices[(vertices.indexOf(a) + 1) % vertices.length];
    return area + a.x * b.y - b.x * a.y;
  });
  if (!signedArea.isFinite || signedArea.abs() < math.pow(1e-9, 2)) {
    throw FormatException('Tiled collision polygon has zero area: $name');
  }
}
