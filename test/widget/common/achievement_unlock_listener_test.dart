import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/achievement_unlock_listener.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toast_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  /// Advances past `ToastBanner.show`'s default 2s hold + its entrance/exit
  /// animation so its `OverlayEntry`/`AnimationController` are fully removed
  /// and disposed before the test ends (otherwise `TickerProviderStateMixin`
  /// asserts on a still-active ticker at teardown).
  Future<void> settleToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  }

  testWidgets(
    'không có AchievementService đăng ký → render child bình thường, không crash',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementUnlockListener(child: Text('game content')),
        ),
      );

      expect(find.text('game content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onUnlock fire → hiện ToastBanner với message mặc định là achievementId',
    (tester) async {
      final service = AchievementService()..register('first_win', 1);
      Get.put(service, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementUnlockListener(child: Text('game content')),
        ),
      );

      service.incrementProgress('first_win', 1);
      await tester.pump();

      expect(find.text('first_win'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await settleToast(tester);
    },
  );

  testWidgets(
    'labelFor cung cấp → hiện đúng label tuỳ chỉnh, không phải id thô',
    (tester) async {
      final service = AchievementService()..register('first_win', 1);
      Get.put(service, permanent: true);

      await tester.pumpWidget(
        MaterialApp(
          home: AchievementUnlockListener(
            labelFor: (id) => id == 'first_win' ? 'First Victory!' : id,
            child: const Text('game content'),
          ),
        ),
      );

      service.incrementProgress('first_win', 1);
      await tester.pump();

      expect(find.text('First Victory!'), findsOneWidget);
      expect(find.text('first_win'), findsNothing);
      await settleToast(tester);
    },
  );

  testWidgets('màu mặc định là NeonTheme.gold khi không truyền color', (
    tester,
  ) async {
    final service = AchievementService()..register('first_win', 1);
    Get.put(service, permanent: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementUnlockListener(child: Text('game content')),
      ),
    );

    service.incrementProgress('first_win', 1);
    await tester.pump();

    final banner = tester.widget<ToastBanner>(find.byType(ToastBanner));
    expect(banner.color, NeonTheme.gold);
    await settleToast(tester);
  });

  testWidgets('color tuỳ chỉnh được truyền đúng xuống ToastBanner', (
    tester,
  ) async {
    final service = AchievementService()..register('first_win', 1);
    Get.put(service, permanent: true);

    await tester.pumpWidget(
      MaterialApp(
        home: AchievementUnlockListener(
          color: NeonTheme.cyan,
          child: const Text('game content'),
        ),
      ),
    );

    service.incrementProgress('first_win', 1);
    await tester.pump();

    final banner = tester.widget<ToastBanner>(find.byType(ToastBanner));
    expect(banner.color, NeonTheme.cyan);
    await settleToast(tester);
  });

  testWidgets(
    'nhiều achievement unlock liên tiếp đều hiện toast riêng, không mất sự kiện nào',
    (tester) async {
      final service = AchievementService()
        ..register('a', 1)
        ..register('b', 1);
      Get.put(service, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementUnlockListener(child: Text('game content')),
        ),
      );

      service.incrementProgress('a', 1);
      await tester.pump();
      service.incrementProgress('b', 1);
      await tester.pump();

      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      await settleToast(tester);
    },
  );

  testWidgets('dispose widget trong lúc chưa có unlock nào không crash', (
    tester,
  ) async {
    final service = AchievementService()..register('first_win', 1);
    Get.put(service, permanent: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementUnlockListener(child: Text('game content')),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Text('other screen')));
    service.incrementProgress('first_win', 1);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('first_win'), findsNothing);
  });

  testWidgets(
    'AchievementService bị dispose (onClose) không làm listener crash',
    (tester) async {
      final service = AchievementService()..register('first_win', 1);
      Get.put(service, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementUnlockListener(child: Text('game content')),
        ),
      );

      await Get.delete<AchievementService>(force: true);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('game content'), findsOneWidget);
    },
  );

  testWidgets(
    'BUG-93: mount TRƯỚC khi AchievementService đăng ký -> service đăng ký '
    'muộn + widget rebuild (didUpdateWidget) -> vẫn nhận được unlock, '
    'không bị treo mãi mãi ở initState với service null',
    (tester) async {
      // Không Get.put service trước — initState chạy với AchievementService.maybe == null.
      var rebuildKey = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Column(
              children: [
                AchievementUnlockListener(child: const Text('game content')),
                TextButton(
                  onPressed: () => setState(() => rebuildKey++),
                  child: const Text('rebuild'),
                ),
              ],
            ),
          ),
        ),
      );

      final service = AchievementService()..register('first_win', 1);
      Get.put(service, permanent: true);

      // Trigger didUpdateWidget bằng cách rebuild parent (không đổi prop nào
      // của AchievementUnlockListener) — cùng cách 1 setState thật của
      // consumer app sau khi service async-register xong sẽ hoạt động.
      await tester.tap(find.text('rebuild'));
      await tester.pump();

      service.incrementProgress('first_win', 1);
      await tester.pump();

      expect(find.text('first_win'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await settleToast(tester);
    },
  );

  testWidgets(
    'BUG-93: AchievementService bị thay thế (Get.delete rồi Get.put service '
    'MỚI) + widget rebuild -> resubscribe sang stream mới, không kẹt ở '
    'stream cũ đã đóng',
    (tester) async {
      final serviceA = AchievementService()..register('first_win', 1);
      Get.put(serviceA, permanent: true);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Column(
              children: [
                AchievementUnlockListener(child: const Text('game content')),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('rebuild'),
                ),
              ],
            ),
          ),
        ),
      );

      serviceA.incrementProgress('first_win', 1);
      await tester.pump();
      expect(find.text('first_win'), findsOneWidget);
      await settleToast(tester);

      await Get.delete<AchievementService>(force: true);
      final serviceB = AchievementService()..register('second_win', 1);
      Get.put(serviceB, permanent: true);

      await tester.tap(find.text('rebuild'));
      await tester.pump();

      serviceB.incrementProgress('second_win', 1);
      await tester.pump();

      expect(find.text('second_win'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await settleToast(tester);
    },
  );
}
