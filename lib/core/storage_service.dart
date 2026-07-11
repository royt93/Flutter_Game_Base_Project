import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tập trung MỌI key lưu trữ — tránh gõ string literal rải rác, dễ sai.
class StorageKeys {
  StorageKeys._();

  static const String unlockedLevel = 'unlockedLevel';
  static const String coins = 'coins';
  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';

  static String highScore(int level) => 'hs_$level';
  static String star(int level) => 'star_$level';

  // Booster (mid-game): bomb (nổ 3x3), shuffle (xáo bàn), undo (revert 1 bước)
  static const String bombCount = 'bomb_count';
  static const String shuffleCount = 'shuffle_count';
  static const String undoCount = 'undo_count';
}

/// Service lưu trữ local dùng chung (bọc SharedPreferences).
/// Đăng ký 1 lần ở main: `Get.put(StorageService(prefs), permanent: true)`.
class StorageService extends GetxService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  int getInt(String key, {int def = 0}) => _prefs.getInt(key) ?? def;
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  bool getBool(String key, {bool def = false}) => _prefs.getBool(key) ?? def;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
