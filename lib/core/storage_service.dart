import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

class StorageKeys {
  StorageKeys._();

  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';
  static const String themeDark = 'theme_dark';

  // 4 extra keys beyond the base project's own 3: lib/core/haptics.dart and
  // lib/core/utils/clamped_clock.dart read/write them directly.
  static const String hapticsEnabled = 'haptics_enabled';
  static const String hapticSoftMode = 'haptic_soft_mode';
  static const String maxEpochDaySeen = 'max_epoch_day_seen';
  static const String maxMsSeen = 'max_ms_seen';
}

/// Service lưu trữ local dùng chung (bọc SharedPreferences).
/// Đăng ký 1 lần ở main: `Get.put(StorageService(prefs), permanent: true)`.
///
/// [_prefs] null khi `SharedPreferences.getInstance()` lỗi lúc boot (thiết bị
/// hiếm, storage hỏng) — dùng [_fallback] in-memory để app vẫn chạy được với
/// giá trị mặc định an toàn thay vì crash trắng màn hình (không persist qua
/// session, nhưng đó là quyền lấy sau, không phải crash).
class StorageService extends GetxService {
  final SharedPreferences? _prefs;
  final Map<String, Object> _fallback = {};
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  /// An toàn khi gọi từ widget test độc lập chưa đăng ký service (vd các
  /// widget hiệu ứng nhỏ như confetti/mascot/pulse-glow test riêng lẻ).
  static StorageService? get maybe =>
      Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;

  /// Số lần thật sự chạm `SharedPreferences` (platform channel + ghi
  /// đĩa). Tăng ở mọi `setX` **không** đi qua buffer, và mỗi key được
  /// [flush] đẩy xuống.
  ///
  /// Tồn tại để có test tất định thay vì phải profile tay trên device khi
  /// một hot path (vd một counter ghi mỗi lần tap trong gameplay) vô tình
  /// ghi thẳng xuống đĩa nhiều lần thay vì qua buffer. Một `int++` không
  /// đáng kể ở runtime, đổi lại có lưới chống hồi quy vĩnh viễn.
  int platformWrites = 0;

  /// Write-behind cho hot path. Giá trị ghi qua `setXBuffered` nằm ở đây
  /// tới khi [flush] đẩy xuống đĩa một lượt.
  ///
  /// **Mọi đường đọc phải tra buffer TRƯỚC `_prefs`** — nếu không, giá trị vừa
  /// ghi mà chưa flush sẽ đọc ra số cũ. Đó là bẫy chính của kiểu tối ưu này,
  /// nên [getInt]/[getBool]/[getString]/[getDouble]/[allKeys]/[exportAll] đều
  /// đã xử lý, và [remove]/[importAll] dọn buffer.
  ///
  /// CHỈ dùng cho counter trên hot path (vd một counter ghi mỗi lần tap
  /// trong gameplay). Giao dịch thật — mua bán, nhận thưởng, reset — phải
  /// ghi ngay bằng `setX` thường: mất chúng khi app bị kill là mất tiền/vật
  /// phẩm của người chơi.
  final Map<String, Object> _buffer = {};

  Future<void> setIntBuffered(String key, int value) async =>
      _buffer[key] = value;

  Future<void> setStringBuffered(String key, String value) async =>
      _buffer[key] = value;

  /// Đẩy toàn bộ giá trị đang đệm xuống đĩa. Gọi ở mốc an toàn: kết thúc màn,
  /// app vào nền, controller đóng, và trước mọi giao dịch có thưởng.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final pending = Map<String, Object>.from(_buffer);
    _buffer.clear();
    for (final entry in pending.entries) {
      final value = entry.value;
      if (value is int) {
        await setInt(entry.key, value);
      } else if (value is String) {
        await setString(entry.key, value);
      } else if (value is bool) {
        await setBool(entry.key, value);
      } else if (value is double) {
        await setDouble(entry.key, value);
      }
    }
  }

  /// Đọc giá trị thô rồi **kiểm kiểu**, không cast thẳng.
  ///
  /// Bản cũ dùng `_prefs.getInt(key)` / `as int?`, mà cả hai đều ném
  /// `TypeError` nếu key đang giữ kiểu khác (String ở chỗ đáng lẽ là int).
  /// Một khi state thật hydrate hàng chục key trong `onInit()` của một
  /// singleton `permanent: true` dựng ngay ở `main.dart`, một key sai kiểu
  /// duy nhất là **app không boot được** — người chơi phải gỡ cài đặt.
  ///
  /// Đường vào có thật: [importAll] chỉ kiểm giá trị thuộc int/bool/double/
  /// String, KHÔNG kiểm từng key có đúng kiểu mong đợi không — một bản
  /// backup hỏng hoặc chỉnh tay chứa `"coins": "abc"` là đủ để trúng lỗi này.
  ///
  /// Sai kiểu → trả mặc định, giống hệt như key chưa tồn tại. Sửa ở đây phủ
  /// **mọi** key một lượt, thay vì bọc try/catch ở từng chỗ hydrate.
  Object? _raw(String key) => _buffer[key] ?? _prefs?.get(key) ?? _fallback[key];

  int getInt(String key, {int def = 0}) {
    final v = _raw(key);
    return v is int ? v : def;
  }
  /// Ghi thẳng phải **huỷ bản đang đệm** của cùng key. Không có dòng
  /// này thì giá trị buffered cũ vẫn che kết quả ở `_raw`, và cú [flush] kế
  /// tiếp ghi đè luôn xuống đĩa — một undo, reset, mua bán hay import đều
  /// lặng lẽ mất tác dụng nếu key đó từng đi qua hot path.
  Future<void> setInt(String key, int value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setInt(key, value);
      return;
    }
    _fallback[key] = value;
  }

  bool getBool(String key, {bool def = false}) {
    final v = _raw(key);
    return v is bool ? v : def;
  }
  /// Xem ghi chú ở [setInt].
  Future<void> setBool(String key, bool value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setBool(key, value);
      return;
    }
    _fallback[key] = value;
  }

  double getDouble(String key, {double def = 1.0}) {
    final v = _raw(key);
    return v is double ? v : def;
  }
  /// Xem ghi chú ở [setInt].
  Future<void> setDouble(String key, double value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setDouble(key, value);
      return;
    }
    _fallback[key] = value;
  }

  String? getString(String key) {
    final v = _raw(key);
    return v is String ? v : null;
  }
  /// Xem ghi chú ở [setInt].
  Future<void> setString(String key, String value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setString(key, value);
      return;
    }
    _fallback[key] = value;
  }

  /// Đọc JSON list (khác pattern CSV-join của các key khác trong file này)
  /// — dùng cho các key cần lưu một danh sách string thay vì 1 giá trị.
  List<String> getStringList(String key) {
    final raw = getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setStringList(String key, List<String> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    // Xoá cả bản đang đệm, nếu không thì giá trị chưa flush sẽ "sống lại"
    // ở lần đọc kế tiếp dù key đã bị xoá khỏi đĩa.
    _buffer.remove(key);
    if (_prefs != null) {
      await _prefs.remove(key);
      return;
    }
    _fallback.remove(key);
  }

  /// Mọi key đang tồn tại. Cùng lý do với [exportAll] — dùng API generic
  /// thay vì hand-list `StorageKeys`, để không có chỗ nào phải nhớ cập nhật
  /// một danh sách tay mỗi khi thêm key mới (một danh sách tay kiểu đó rất
  /// dễ trôi lạc hậu qua vài round code review).
  Set<String> allKeys() =>
      {...?_prefs?.getKeys(), ..._fallback.keys, ..._buffer.keys};

  /// Dump toàn bộ storage hiện có thành map — dùng API generic của
  /// SharedPreferences (getKeys/get) thay vì hand-list từng StorageKeys, để
  /// không phải nhớ cập nhật danh sách này mỗi khi thêm key mới.
  Map<String, Object> exportAll() {
    final prefs = _prefs;
    // Giá trị đang đệm phải đè lên bản trên đĩa — backup/export đọc qua
    // đây và cần trạng thái mới nhất, kể cả phần chưa flush.
    if (prefs == null) return {..._fallback, ..._buffer};
    return {
      for (final k in prefs.getKeys()) k: prefs.get(k) as Object,
      ..._buffer,
    };
  }

  /// Ghi đè storage từ map đã export. Giá trị chỉ có thể là int/bool/double/
  /// String (StorageService không bao giờ set List thẳng xuống
  /// SharedPreferences — [setStringList] tự JSON-encode thành String).
  Future<void> importAll(Map<String, Object?> data) async {
    if (data.values.any(
      (value) =>
          value is! int &&
          value is! bool &&
          value is! double &&
          value is! String,
    )) {
      throw const FormatException('Unsupported backup value type');
    }
    final normalized = <String, Object>{
      for (final entry in data.entries) entry.key: entry.value!,
    };
    final previous = exportAll();
    // Import ghi đè toàn bộ profile — mọi giá trị đang đệm không còn ý
    // nghĩa và sẽ ghi đè ngược lên dữ liệu vừa khôi phục nếu flush sau đó.
    _buffer.clear();
    try {
      await _replaceAll(normalized);
    } catch (error) {
      // SharedPreferences has no transaction primitive. Re-apply the
      // snapshot so a partial write cannot leave a half-restored profile.
      try {
        await _replaceAll(previous);
      } catch (rollbackError) {
        // Preserve the original failure; callers still show a restore error.
        dlog('roy93~ importAll rollback thất bại: $rollbackError');
      }
      rethrow;
    }
  }

  Future<void> _replaceAll(Map<String, Object> data) async {
    final prefs = _prefs;
    if (prefs != null) {
      for (final key in prefs.getKeys().toList()) {
        await prefs.remove(key);
      }
    } else {
      _fallback.clear();
    }
    for (final entry in data.entries) {
      final value = entry.value;
      switch (value) {
        case int v:
          await setInt(entry.key, v);
        case bool v:
          await setBool(entry.key, v);
        case double v:
          await setDouble(entry.key, v);
        case String v:
          await setString(entry.key, v);
      }
    }
  }
}
