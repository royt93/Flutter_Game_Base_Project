import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('AchievementService', () {
    test('rejects invalid registration before mutation', () {
      final service = AchievementService();

      expect(() => service.register('', 1), throwsArgumentError);
      expect(() => service.register('empty', 0), throwsArgumentError);
      expect(() => service.register('negative', -1), throwsArgumentError);
      expect(service.isCompleted('empty'), isFalse);
    });

    test('rejects invalid increments before mutation/write', () {
      final service = AchievementService();
      service.register('wins', 10);

      expect(() => service.incrementProgress('', 1), throwsArgumentError);
      expect(() => service.incrementProgress('wins', 0), throwsArgumentError);
      expect(() => service.incrementProgress('wins', -1), throwsArgumentError);
      expect(service.isCompleted('wins'), isFalse);
    });

    test(
      'drops corrupt progress entries instead of crashing hydration',
      () async {
        await storage.setString(
          'achievement_progress_v1',
          '{"good":2,"wrongType":"3","negative":-4,"":9,"schemaVersion":1}',
        );
        final service = AchievementService();
        service.register('good', 3);
        service.register('wrongType', 3);
        service.register('negative', 1);

        expect(service.isCompleted('good'), isFalse);
        expect(service.isCompleted('wrongType'), isFalse);
        expect(service.isCompleted('negative'), isFalse);
        expect(() => service.isCompleted('missing'), returnsNormally);
      },
    );

    test('rejects integer overflow without changing progress', () {
      final service = AchievementService();
      service.register('wins', 10);
      service.incrementProgress('wins', 1);

      expect(
        () => service.incrementProgress('wins', 9223372036854775807),
        throwsRangeError,
      );
      expect(service.isCompleted('wins'), isFalse);
    });

    testWidgets('widget can render safely after corrupt progress recovery', (
      tester,
    ) async {
      await storage.setString(
        'achievement_progress_v1',
        '{"broken":"yes","schemaVersion":1}',
      );
      final service = AchievementService()..register('wins', 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (_) =>
                Text(service.isCompleted('wins') ? 'done' : 'safe'),
          ),
        ),
      );

      expect(find.text('safe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    test('maybe trả về null khi chưa Get.put', () {
      expect(AchievementService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = AchievementService();
      Get.put(service, permanent: true);
      expect(AchievementService.maybe, same(service));
    });

    test('chưa đạt ngưỡng thì isCompleted trả về false', () {
      final service = AchievementService();
      service.register('first_win', 3);

      service.incrementProgress('first_win', 2);

      expect(service.isCompleted('first_win'), false);
    });

    test('tăng progress đủ ngưỡng thì isCompleted trả về true', () {
      final service = AchievementService();
      service.register('first_win', 3);

      service.incrementProgress('first_win', 3);

      expect(service.isCompleted('first_win'), true);
    });

    test(
      'tăng progress vượt ngưỡng nhiều lần không lỗi, không "unlock lại"',
      () {
        final service = AchievementService();
        service.register('first_win', 3);

        service.incrementProgress('first_win', 3);
        expect(service.isCompleted('first_win'), true);

        // Gọi thêm nhiều lần sau khi đã hoàn thành — không được throw,
        // isCompleted phải giữ nguyên true.
        expect(
          () => service.incrementProgress('first_win', 5),
          returnsNormally,
        );
        expect(
          () => service.incrementProgress('first_win', 100),
          returnsNormally,
        );
        expect(service.isCompleted('first_win'), true);
      },
    );

    test(
      'achievement chưa register thì isCompleted trả về false, không throw',
      () {
        final service = AchievementService();
        expect(() => service.isCompleted('unknown'), returnsNormally);
        expect(service.isCompleted('unknown'), false);
      },
    );

    test('incrementProgress cộng dồn đúng qua nhiều lần gọi', () {
      final service = AchievementService();
      service.register('collect_10', 10);

      service.incrementProgress('collect_10', 4);
      service.incrementProgress('collect_10', 4);
      expect(service.isCompleted('collect_10'), false);

      service.incrementProgress('collect_10', 2);
      expect(service.isCompleted('collect_10'), true);
    });

    test(
      'progress persist qua restart (instance mới đọc lại từ StorageService)',
      () {
        final service1 = AchievementService();
        service1.register('first_win', 3);
        service1.incrementProgress('first_win', 3);
        expect(service1.isCompleted('first_win'), true);

        // "Restart": instance mới, cùng StorageService đã Get.put ở setUp.
        final service2 = AchievementService();
        service2.register('first_win', 3);
        expect(service2.isCompleted('first_win'), true);
      },
    );

    test('progress chưa đủ ngưỡng cũng persist đúng qua restart', () {
      final service1 = AchievementService();
      service1.register('first_win', 3);
      service1.incrementProgress('first_win', 1);

      final service2 = AchievementService();
      service2.register('first_win', 3);
      service2.incrementProgress('first_win', 1);

      expect(service2.isCompleted('first_win'), false);
      service2.incrementProgress('first_win', 1);
      expect(service2.isCompleted('first_win'), true);
    });

    group('BUG-17: save race khi nhiều incrementProgress gọi rất nhanh', () {
      test('N lần incrementProgress liên tiếp không await → sau khi mọi save '
          'settle, tổng persist đúng qua instance mới (không bị 1 write cũ '
          'ghi đè bằng snapshot lỗi thời)', () async {
        final service = AchievementService();
        service.register('combo', 100);

        // 10 lần gọi LIÊN TIẾP không await gì giữa các lần — đúng kịch bản
        // "combo nhiều event cùng lúc" mô tả trong Hiện trạng. Trước khi
        // sửa, các lệnh save() (unawaited) chạy song song và có thể hoàn
        // tất sai thứ tự; sau khi sửa, _saveChain đảm bảo mỗi save chỉ bắt
        // đầu khi save trước đã xong, nên write SAU CÙNG luôn hoàn tất
        // SAU CÙNG bất kể tốc độ I/O thật.
        for (var i = 0; i < 10; i++) {
          service.incrementProgress('combo', 1);
        }

        await service.debugPendingSaves;

        final reloaded = AchievementService();
        reloaded.register('combo', 100);
        expect(reloaded.isCompleted('combo'), isFalse);
        // isCompleted không lộ ra tổng thật — đọc trực tiếp qua storage để
        // xác nhận đúng 10, không phải 1 giá trị trung gian nào bị kẹt lại.
        expect(
          storage.getString('achievement_progress_v1'),
          contains('"combo":10'),
        );
      });

      test(
        'mỗi incrementProgress trong burst đều thực sự ghi xuống disk — '
        'không bị âm thầm rớt/gộp lại (đếm qua StorageService.platformWrites)',
        () async {
          final service = AchievementService();
          service.register('combo', 100);

          final writesBefore = storage.platformWrites;
          for (var i = 0; i < 5; i++) {
            service.incrementProgress('combo', 1);
          }
          await service.debugPendingSaves;

          // >= 5 (không phải == 5): mỗi save() còn gọi nowMsClamped(), có
          // thể tự thêm 1 write phụ (StorageKeys.maxMsSeen) lần đầu tiên
          // watermark đó được nâng lên trong test — không liên quan tới
          // đúng/sai của serialization đang test ở đây. Điều thực sự cần
          // đảm bảo: không có save nào trong 5 lần bị rớt/gộp mất, tức tổng
          // write phải đạt ÍT NHẤT 5.
          expect(
            storage.platformWrites - writesBefore,
            greaterThanOrEqualTo(5),
          );
        },
      );
    });

    group('IDEA-43: onUnlock stream', () {
      test('phát đúng 1 lần khi progress chạm ngưỡng lần đầu', () async {
        final service = AchievementService();
        service.register('wins', 3);
        final events = <String>[];
        service.onUnlock.listen(events.add);

        service.incrementProgress('wins', 1);
        service.incrementProgress('wins', 1);
        await pumpEventQueue();
        expect(events, isEmpty);

        service.incrementProgress('wins', 1);
        await pumpEventQueue();
        expect(events, ['wins']);
      });

      test(
        'không phát lại khi tiếp tục incrementProgress sau khi đã unlock',
        () async {
          final service = AchievementService();
          service.register('wins', 1);
          final events = <String>[];
          service.onUnlock.listen(events.add);

          service.incrementProgress('wins', 1);
          service.incrementProgress('wins', 5);
          service.incrementProgress('wins', 10);
          await pumpEventQueue();

          expect(events, ['wins']);
        },
      );

      test(
        '1 lần incrementProgress nhảy thẳng qua ngưỡng (amount lớn) vẫn phát đúng 1 lần',
        () async {
          final service = AchievementService();
          service.register('wins', 10);
          final events = <String>[];
          service.onUnlock.listen(events.add);

          service.incrementProgress('wins', 999);
          await pumpEventQueue();

          expect(events, ['wins']);
        },
      );

      test('register() không bao giờ tự phát unlock dù threshold đã đạt sẵn', () async {
        final service = AchievementService();
        service.register('wins', 100);
        service.incrementProgress('wins', 100);
        await pumpEventQueue();

        final events = <String>[];
        // Đăng ký lại với threshold thấp hơn giá trị progress đã có sẵn —
        // register() tự nó không được phép phát unlock, chỉ incrementProgress
        // mới là điểm kích hoạt sự kiện.
        service.register('wins', 1);
        service.onUnlock.listen(events.add);
        await pumpEventQueue();

        expect(events, isEmpty);
      });

      test('nhiều achievement id khác nhau phát đúng, độc lập với nhau', () async {
        final service = AchievementService();
        service.register('a', 1);
        service.register('b', 1);
        final events = <String>[];
        service.onUnlock.listen(events.add);

        service.incrementProgress('a', 1);
        service.incrementProgress('b', 1);
        await pumpEventQueue();

        expect(events, containsAll(['a', 'b']));
        expect(events.length, 2);
      });

      test('onUnlock là broadcast stream — nhiều listener cùng nhận được sự kiện', () async {
        final service = AchievementService();
        service.register('wins', 1);
        final eventsA = <String>[];
        final eventsB = <String>[];
        service.onUnlock.listen(eventsA.add);
        service.onUnlock.listen(eventsB.add);

        service.incrementProgress('wins', 1);
        await pumpEventQueue();

        expect(eventsA, ['wins']);
        expect(eventsB, ['wins']);
      });
    });
  });
}
