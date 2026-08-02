import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

/// I40: kiểu particle thời tiết nền theo world. `none` = không có lớp
/// weather (mặc định, và luôn dùng cho world cuối để không chồng aurora I16).
enum WeatherKind { none, snow, spark, bubble }

/// F4: 1 world = 20 màn campaign liên tiếp, có tông màu + tên riêng cho
/// banner trên [LevelSelectScreen].
class GameWorld {
  final String nameKey; // i18n key, .tr ở nơi hiển thị
  final Color color;
  final int startId; // inclusive
  final int endId; // inclusive
  final IconData icon; // hoạ tiết nền banner, không dùng asset ảnh
  final WeatherKind weather; // I40: particle nền, none = không có

  const GameWorld({
    required this.nameKey,
    required this.color,
    required this.startId,
    required this.endId,
    required this.icon,
    this.weather = WeatherKind.none,
  });

  bool contains(int levelId) => levelId >= startId && levelId <= endId;
}

const List<GameWorld> kWorlds = [
  GameWorld(
    nameKey: 'world_path_name_1',
    color: NeonTheme.pink,
    startId: 1,
    endId: 20,
    icon: Icons.favorite_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_2',
    color: NeonTheme.orange,
    startId: 21,
    endId: 40,
    icon: Icons.local_fire_department_rounded,
    weather: WeatherKind.spark,
  ),
  GameWorld(
    nameKey: 'world_path_name_3',
    color: NeonTheme.teal,
    startId: 41,
    endId: 60,
    icon: Icons.water_drop_rounded,
    weather: WeatherKind.bubble,
  ),
  GameWorld(
    nameKey: 'world_path_name_4',
    color: NeonTheme.magenta,
    startId: 61,
    endId: 80,
    icon: Icons.auto_awesome_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_5',
    color: NeonTheme.yellow,
    startId: 81,
    endId: 100,
    icon: Icons.wb_sunny_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_6',
    color: NeonTheme.purple,
    startId: 101,
    endId: 120,
    icon: Icons.nights_stay_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_7',
    color: NeonTheme.blue,
    startId: 121,
    endId: 140,
    icon: Icons.ac_unit_rounded,
    weather: WeatherKind.snow,
  ),
  GameWorld(
    nameKey: 'world_path_name_8',
    color: NeonTheme.red,
    startId: 141,
    endId: 160,
    icon: Icons.whatshot_rounded,
    weather: WeatherKind.spark,
  ),
  GameWorld(
    nameKey: 'world_path_name_9',
    color: NeonTheme.cyan,
    startId: 161,
    endId: 180,
    icon: Icons.waves_rounded,
    weather: WeatherKind.bubble,
  ),
  GameWorld(
    nameKey: 'world_path_name_10',
    color: NeonTheme.indigo,
    startId: 181,
    endId: 200,
    icon: Icons.stars_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_11',
    color: NeonTheme.gold,
    startId: 201,
    endId: 220,
    icon: Icons.diamond_rounded,
  ),
];

GameWorld worldForLevel(int id) =>
    kWorlds.firstWhere((w) => w.contains(id), orElse: () => kWorlds.last);
