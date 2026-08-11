import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration cho [X28] / [X18] — **save hỏng không được chặn boot**.
///
/// Unit test (`test/presentation/save_fuzz_test.dart`) dựng `GameController`
/// trực tiếp, nên nó chỉ chứng minh *controller* chịu được dữ liệu xấu. Đường
/// khởi động thật còn có `AudioManager`, `ReminderService`, `LocaleService`,
/// `HomeWidgetSync` và thứ tự `Get.put` trong `main.dart` — một key hỏng có
/// thể làm gãy ở đó mà unit test không thấy.
///
/// Test này gieo save sai kiểu **trước** khi gọi `app.app()`, tức tái hiện
/// đúng tình huống người chơi mở app sau khi import một mã backup giả mạo
/// (`importAll` không kiểm kiểu từng key, và khoá backup nằm sẵn trong binary
/// — xem `logic/backup_code.dart`).
///
/// Chạy: `flutter test integration_test/save_resilience_test.dart -d <device>`
Future<void> _pumpBounded(
  WidgetTester tester, {
  int times = 15,
  Duration step = const Duration(milliseconds: 300),
}) async {
  // Không dùng pumpAndSettle: StarMascot chạy AnimationController.repeat()
  // vô hạn nên nó không bao giờ ổn định (xem lifecycle_test.dart).
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

/// Ghi giá trị **sai kiểu** vào các key mà app đọc bằng `getInt`.
///
/// `SharedPreferences.setString` cho phép làm việc này ở tầng Dart, đúng như
/// một mã backup giả mạo làm được — không cần root hay sửa file XML.
Future<void> _corruptSave() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.coins, 'abc');
  await prefs.setString(StorageKeys.unlockedLevel, 'không-phải-số');
  await prefs.setString(StorageKeys.maxEpochDaySeen, '[]');
  await prefs.setString(StorageKeys.loginStreakCount, '{}');
  await prefs.setString(StorageKeys.totalGemsPopped, 'null');
  await prefs.setString(StorageKeys.prestigeTier, '-');
  // Key kiểu chuỗi nhưng chứa JSON hỏng — nhánh hydrate của X18.
  await prefs.setString(StorageKeys.starOwnedPets, '[{"typeId":');
  await prefs.setString(StorageKeys.achievementUnlockDays, 'không-phải-json');
  // Key bool nhận số.
  await prefs.setInt(StorageKeys.colorblindMode, 7);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app vẫn boot khi save chứa giá trị sai kiểu', (tester) async {
    await _corruptSave();

    await app.app(withAudio: false);
    await _pumpBounded(tester);

    expect(
      tester.takeException(),
      isNull,
      reason:
          'Startup ném với save sai kiểu = app không mở được, người chơi phải '
          'gỡ cài đặt và mất sạch tiến độ (X28).',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('key sai kiểu rơi về mặc định, không giữ rác', (tester) async {
    await _corruptSave();

    await app.app(withAudio: false);
    await _pumpBounded(tester);

    final ctrl = Get.find<GameController>();
    // Sai kiểu phải được đối xử y hệt "key chưa tồn tại".
    expect(ctrl.coins.value, 0);
    expect(ctrl.unlockedLevel.value, 1);
    expect(ctrl.prestigeTier.value, 0);
    expect(ctrl.totalGemsPopped.value, 0);
    expect(ctrl.colorblindMode.value, isFalse);
    expect(ctrl.starOwnedPets, isEmpty);
    expect(
      ctrl.achievementUnlockDays,
      isEmpty,
      reason: 'JSON hỏng bị bỏ, không làm hỏng cả feed',
    );
  });

  testWidgets('chơi được bình thường sau khi boot từ save hỏng', (
    tester,
  ) async {
    await _corruptSave();

    await app.app(withAudio: false);
    await _pumpBounded(tester);

    // Ghi giá trị hợp lệ đè lên chỗ vừa hỏng rồi đọc lại — xác nhận storage
    // không kẹt ở trạng thái xấu sau khi đã đọc trượt một lần.
    final store = StorageService.to;
    await store.setInt(StorageKeys.coins, 123);
    expect(store.getInt(StorageKeys.coins), 123);

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
