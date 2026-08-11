import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T4 phần A — fuzz hydrate.
///
/// [X18] không phải bug logic mà là bug **bảo trì**: `GameController._load()`
/// hydrate ~25 hệ từ storage, 24 chỗ có guard, 1 chỗ quên → save hỏng làm app
/// không boot được. Vá riêng chỗ đó không ngăn được chỗ thứ 26.
///
/// Test này **tự phát hiện key mới**: nó đọc chính `storage_service.dart` và
/// rút mọi `static const String` ra, nên thêm key mà quên guard là đỏ ngay,
/// không ai phải nhớ cập nhật danh sách. Cùng thủ pháp với
/// `campaign_total_sweep_test.dart` (đọc file từ đĩa để chống trôi số liệu).
///
/// Đánh đổi: phụ thuộc vào cách viết source (regex trên `static const String`).
/// Nếu `StorageKeys` đổi sang enum/generated code thì test này phải sửa theo —
/// đã assert số key tối thiểu để hỏng regex không âm thầm biến fuzz thành no-op.
List<String> _allStorageKeyValues() {
  final src = File('lib/core/storage_service.dart').readAsStringSync();
  final classStart = src.indexOf('class StorageKeys');
  final classEnd = src.indexOf('class StorageService');
  final body = src.substring(classStart, classEnd);
  final re = RegExp(r"static const String \w+ =\s*'([^']*)'");
  return re.allMatches(body).map((m) => m.group(1)!).toList();
}

/// Giá trị rác đại diện cho các cách một save có thể hỏng thật:
/// file ghi dở, backup giả mạo, hoặc hạ version sau khi format đổi.
const _garbage = <String, Object>{
  'chuỗi rỗng': '',
  'không phải JSON': 'không-phải-json',
  'JSON object': '{}',
  'JSON array rỗng': '[]',
  'JSON array sai kiểu': '[1,2,3]',
  'JSON cụt': '[{"a":',
  'null literal': 'null',
  'số âm khổng lồ': -9223372036854775808,
  'số 0': 0,
  'bool': true,
};

Future<void> _bootWith(String key, Object value) async {
  SharedPreferences.setMockInitialValues({key: value});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('rút được danh sách key từ source (regex chưa mục)', () {
    final keys = _allStorageKeyValues();
    expect(
      keys.length,
      greaterThanOrEqualTo(90),
      reason:
          'Chỉ rút được ${keys.length} key — regex nhiều khả năng đã mục sau '
          'khi StorageKeys đổi cách viết. Fuzz bên dưới sẽ thành no-op âm '
          'thầm nếu không bắt ở đây.',
    );
    // `widgetStreakKey`/`widgetCoinsKey` cố ý trùng tên với key game
    // (`'coins'`) vì chúng thuộc namespace KHÁC — storage riêng của home
    // widget, do `StreakWidgetProvider.kt` đọc, không phải SharedPreferences
    // của app. Loại chúng ra trước khi kiểm trùng.
    final appKeys = keys.toList()
      ..remove(StorageKeys.widgetStreakKey)
      ..remove(StorageKeys.widgetCoinsKey);
    expect(
      appKeys.toSet().length,
      appKeys.length,
      reason: 'hai key game trùng chuỗi → chúng ghi đè nhau trên đĩa',
    );
  });

  test('MỌI key chứa giá trị rác đều không chặn boot', () async {
    final keys = _allStorageKeyValues();
    final failures = <String>[];

    for (final key in keys) {
      for (final entry in _garbage.entries) {
        try {
          await _bootWith(key, entry.value);
        } catch (e) {
          failures.add('$key = ${entry.key} -> ${e.runtimeType}: $e');
        } finally {
          Get.reset();
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'Save hỏng ở ${failures.length} tổ hợp làm GameController.onInit() '
          'ném. GameController là `permanent: true` dựng trong main.dart, nên '
          'ném ở đây = APP KHÔNG BOOT ĐƯỢC, người chơi phải gỡ cài đặt và mất '
          'sạch tiến độ.\n\n${failures.take(25).join('\n')}',
    );
  });

  test(
    'key động (highScore/star/remixBest) chứa rác cũng không chặn boot',
    () async {
      final failures = <String>[];
      final dynamicKeys = [
        StorageKeys.highScore(1),
        StorageKeys.highScore(260),
        StorageKeys.star(1),
        StorageKeys.star(260),
        StorageKeys.remixBest(1),
      ];

      for (final key in dynamicKeys) {
        for (final entry in _garbage.entries) {
          try {
            await _bootWith(key, entry.value);
          } catch (e) {
            failures.add('$key = ${entry.key} -> ${e.runtimeType}: $e');
          } finally {
            Get.reset();
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );

  test('nhiều key hỏng cùng lúc vẫn boot (save hỏng diện rộng)', () async {
    final keys = _allStorageKeyValues();
    SharedPreferences.setMockInitialValues({
      for (final k in keys) k: 'rác-toàn-tập',
    });
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);

    expect(
      () => Get.put(GameController(), permanent: true),
      returnsNormally,
      reason: 'file save hỏng toàn bộ vẫn phải mở được app',
    );
  });
}
