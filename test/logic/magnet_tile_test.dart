import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/magnet_tile.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';

void main() {
  test('returns matching magnet coordinates and ignores other colors', () {
    final grid = <List<int?>>[
      [encodeMagnetTile(2), 2, encodeMagnetTile(4)],
      [null, encodeMagnetTile(2), 4],
    ];
    expect(magnetTilesTriggeredBy(grid, 2), [(0, 0), (1, 1)]);
    expect(magnetTilesTriggeredBy(grid, 7), isEmpty);
  });

  test('multiple colors only trigger the matching magnet', () {
    final grid = <List<int?>>[
      [encodeMagnetTile(1), encodeMagnetTile(3)],
    ];
    expect(magnetTilesTriggeredBy(grid, 3), [(0, 1)]);
  });

  test('encoding round-trips all supported colors', () {
    for (var color = 0; color <= 7; color++) {
      final encoded = encodeMagnetTile(color);
      expect(isMagnetId(encoded), isTrue);
      expect(magnetColorIndex(encoded), color);
    }
  });

  test('magnet tiles cannot be tapped or join flood-fill groups', () {
    final grid = <List<int?>>[
      [encodeMagnetTile(2), 2],
      [2, 2],
    ];
    expect(findConnectedGroup(grid, 0, 0), isEmpty);
    expect(findConnectedGroup(grid, 0, 1), {
      const Point(0, 1),
      const Point(1, 1),
      const Point(1, 0),
    });
  });
}
