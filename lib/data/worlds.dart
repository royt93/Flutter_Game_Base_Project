import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

/// F4: 1 world = 20 màn campaign liên tiếp, có tông màu + tên riêng cho
/// banner trên [LevelSelectScreen].
class GameWorld {
  final String nameKey; // i18n key, .tr ở nơi hiển thị
  final Color color;
  final int startId; // inclusive
  final int endId; // inclusive

  const GameWorld({
    required this.nameKey,
    required this.color,
    required this.startId,
    required this.endId,
  });

  bool contains(int levelId) => levelId >= startId && levelId <= endId;
}

const List<GameWorld> kWorlds = [
  GameWorld(
    nameKey: 'world_path_name_1',
    color: NeonTheme.pink,
    startId: 1,
    endId: 20,
  ),
  GameWorld(
    nameKey: 'world_path_name_2',
    color: NeonTheme.orange,
    startId: 21,
    endId: 40,
  ),
  GameWorld(
    nameKey: 'world_path_name_3',
    color: NeonTheme.teal,
    startId: 41,
    endId: 60,
  ),
  GameWorld(
    nameKey: 'world_path_name_4',
    color: NeonTheme.magenta,
    startId: 61,
    endId: 80,
  ),
  GameWorld(
    nameKey: 'world_path_name_5',
    color: NeonTheme.yellow,
    startId: 81,
    endId: 100,
  ),
  GameWorld(
    nameKey: 'world_path_name_6',
    color: NeonTheme.purple,
    startId: 101,
    endId: 120,
  ),
  GameWorld(
    nameKey: 'world_path_name_7',
    color: NeonTheme.blue,
    startId: 121,
    endId: 140,
  ),
  GameWorld(
    nameKey: 'world_path_name_8',
    color: NeonTheme.red,
    startId: 141,
    endId: 160,
  ),
  GameWorld(
    nameKey: 'world_path_name_9',
    color: NeonTheme.cyan,
    startId: 161,
    endId: 180,
  ),
  GameWorld(
    nameKey: 'world_path_name_10',
    color: NeonTheme.indigo,
    startId: 181,
    endId: 200,
  ),
];

GameWorld worldForLevel(int id) =>
    kWorlds.firstWhere((w) => w.contains(id), orElse: () => kWorlds.last);
