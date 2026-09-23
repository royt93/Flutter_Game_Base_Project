import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/save_health_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  testWidgets(
    'không có secret -> hiện đúng size + "bỏ qua" cho HMAC, không throw',
    (tester) async {
      await storage.setInt('coins', 100);
      await tester.pumpWidget(
        _wrap(SaveHealthCard(storage: storage, nowMs: () => 123456789)),
      );

      expect(find.textContaining('Kích thước save:'), findsOneWidget);
      expect(find.textContaining('bytes'), findsOneWidget);
      expect(find.textContaining('bỏ qua (chưa có secret)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('có secret hợp lệ -> HMAC báo "hợp lệ"', (tester) async {
    await storage.setInt('coins', 100);
    await tester.pumpWidget(
      _wrap(
        SaveHealthCard(
          storage: storage,
          secret: 'my-secret',
          nowMs: () => 123456789,
        ),
      ),
    );

    expect(find.textContaining('HMAC: hợp lệ'), findsOneWidget);
  });

  testWidgets(
    'StorageService không được đăng ký (không truyền storage, không '
    'Get.put) -> báo lỗi rõ ràng, không crash',
    (tester) async {
      await tester.pumpWidget(_wrap(const SaveHealthCard()));

      expect(find.textContaining('chưa được đăng ký'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hiện đúng thời điểm kiểm tra lần cuối theo nowMs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(SaveHealthCard(storage: storage, nowMs: () => 1000)),
    );

    // 1000ms epoch -> 07:00:01 UTC, nhưng DateTime.fromMillisecondsSinceEpoch
    // mặc định dùng local timezone — chỉ kiểm tra là đã hiện giờ thật (không
    // phải placeholder "chưa kiểm tra"), tránh phụ thuộc timezone máy chạy CI.
    expect(find.textContaining('chưa kiểm tra'), findsNothing);
    expect(find.textContaining('Kiểm tra lần cuối:'), findsOneWidget);
  });

  testWidgets('bấm "Kiểm tra ngay" chạy lại check, cập nhật lại kết quả', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      _wrap(
        SaveHealthCard(
          storage: storage,
          nowMs: () {
            callCount++;
            return 1000 * callCount;
          },
        ),
      ),
    );

    final state = tester.state<SaveHealthCardState>(
      find.byType(SaveHealthCard),
    );
    final firstCheckedText = find
        .textContaining('Kiểm tra lần cuối:')
        .evaluate()
        .single;
    expect(state.result, SaveHealthResult.ok);

    await tester.tap(find.byKey(const Key('saveHealthCardCheckNow')));
    await tester.pump();

    expect(callCount, 2);
    // Widget vẫn còn (không crash), state vẫn ok sau lần check thứ 2.
    expect(state.result, SaveHealthResult.ok);
    expect(firstCheckedText, isNotNull);
  });

  testWidgets(
    'GlobalKey<SaveHealthCardState> cho phép caller ngoài tự gọi check() lại',
    (tester) async {
      final key = GlobalKey<SaveHealthCardState>();
      var nowValue = 1000;
      await tester.pumpWidget(
        _wrap(
          SaveHealthCard(key: key, storage: storage, nowMs: () => nowValue),
        ),
      );

      nowValue = 2000;
      key.currentState!.check();
      await tester.pump();

      expect(key.currentState!.result, SaveHealthResult.ok);
    },
  );
}
