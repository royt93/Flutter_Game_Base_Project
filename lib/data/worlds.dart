import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import 'gauntlet_modifiers.dart';

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
  GameWorld(
    nameKey: 'world_path_name_12',
    color: NeonTheme.lime,
    startId: 221,
    endId: 240,
    icon: Icons.auto_awesome_motion_rounded,
  ),
  GameWorld(
    nameKey: 'world_path_name_13',
    color: NeonTheme.coral,
    startId: 241,
    endId: 260,
    icon: Icons.filter_vintage_rounded,
  ),
];

GameWorld worldForLevel(int id) =>
    kWorlds.firstWhere((w) => w.contains(id), orElse: () => kWorlds.last);

/// I81: luật gameplay gắn với từng [WeatherKind] — khai báo **tập trung ở đây**
/// chứ không rải `if (weather == ...)` khắp engine, và tái dùng thẳng
/// [GauntletModifier] (khuôn đã phục vụ Gauntlet/Treasure Map/Remix) thay vì
/// dựng loại modifier thứ hai.
///
/// ## Vì sao chỉ có luật CỘNG THÊM
///
/// Bàn campaign không refill, nên `targetScore` chỉ đạt được nếu neo theo số ô
/// (xem "Target achievability" trong CLAUDE.md). Bất kỳ luật nào **giảm số ô
/// khả dụng hoặc giảm điểm** đều có thể khiến cả một world thành bất khả thi.
///
/// `test/data/levels_achievability_test.dart` mô phỏng bàn **màu thuần** —
/// không obstacle, không ice. Nó **không** chứng minh được một luật kiểu "tăng
/// mật độ ice" là an toàn. Vì vậy hai luật dưới đây đều thuộc loại chỉ-thêm:
/// cửa sổ combo dài hơn và điểm thưởng nhóm lớn. Cả hai đúng theo cấu trúc là
/// không thể làm màn khó hơn, nên achievability giữ nguyên mà không cần chạy
/// lại mô phỏng với từng world.
///
/// [WeatherKind.snow] (tăng ice) **cố ý chưa làm**: nó là luật trừ đi đầu tiên
/// và cần mở rộng bộ mô phỏng achievability để mô hình hoá ice trước. Ship mù
/// là cách nhanh nhất phá cân bằng 260 màn.
const Map<WeatherKind, GauntletModifier> kWeatherRules = {
  WeatherKind.bubble: GauntletModifier(
    id: 'weather_bubble',
    icon: Icons.bubble_chart_rounded,
    nameKey: 'weather_bubble_name',
    descKey: 'weather_bubble_desc',
    comboWindowOverride: 3.5,
  ),
  WeatherKind.spark: GauntletModifier(
    id: 'weather_spark',
    icon: Icons.auto_awesome_rounded,
    nameKey: 'weather_spark_name',
    descKey: 'weather_spark_desc',
    bigGroupBonus: 1.2,
  ),
};

/// Luật thời tiết của màn campaign [id], `null` nếu world đó không có luật.
///
/// Trả `null` cho mọi id <= 0: side-mode dùng `PopLevel` tổng hợp không thuộc
/// world nào, và [worldForLevel] có `orElse` trả world cuối nên nếu không chặn
/// ở đây thì side-mode sẽ ăn luật của world 13.
GauntletModifier? weatherRuleForLevel(int id) {
  if (id <= 0) return null;
  return kWeatherRules[worldForLevel(id).weather];
}
