import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/daily_quest_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `_realDay` anchors to the real day at test run time — every "simulated
/// day" in this file is `_realDay + offset` (offset >= 0), written straight
/// to `StorageKeys.maxEpochDaySeen`. `todayEpochDayClamped()` returns
/// max(real day, stored watermark), so with offset >= 0 the returned value
/// always equals the watermark just set — simulates "N days later" without
/// waiting on the real clock and without depending on wall-clock time when
/// the test runs (no midnight-boundary flakiness).
int get _realDay => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  Future<void> setDay(int day) =>
      storage.setInt(StorageKeys.maxEpochDaySeen, day);

  group('DailyQuestService: register', () {
    test('rejects invalid registration before mutation', () {
      final service = DailyQuestService();

      expect(() => service.register('', 1), throwsArgumentError);
      expect(() => service.register('empty', 0), throwsArgumentError);
      expect(() => service.register('negative', -1), throwsArgumentError);
      expect(service.isCompleted('empty'), isFalse);
    });

    test('quest chưa register: mọi getter trả về giá trị rỗng, không throw', () {
      final service = DailyQuestService();

      expect(() => service.isCompleted('unknown'), returnsNormally);
      expect(service.isCompleted('unknown'), isFalse);
      expect(service.isClaimed('unknown'), isFalse);
      expect(service.progressOf('unknown'), 0);
      expect(service.targetOf('unknown'), isNull);
    });

    test('register lại cùng id chỉ cập nhật target, không đụng progress', () {
      final service = DailyQuestService();
      service.register('win_3', 3);
      service.incrementProgress('win_3', 2);

      service.register('win_3', 5);

      expect(service.progressOf('win_3'), 2);
      expect(service.targetOf('win_3'), 5);
    });
  });

  group('DailyQuestService: incrementProgress', () {
    test('quest chưa register throw StateError, không mutation', () {
      final service = DailyQuestService();

      expect(
        () => service.incrementProgress('unknown', 1),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects invalid amount before mutation/write', () {
      final service = DailyQuestService();
      service.register('win_3', 3);

      expect(
        () => service.incrementProgress('win_3', 0),
        throwsArgumentError,
      );
      expect(
        () => service.incrementProgress('win_3', -1),
        throwsArgumentError,
      );
      expect(service.progressOf('win_3'), 0);
    });

    test('cộng dồn đúng qua nhiều lần gọi, chưa đạt target thì chưa completed', () {
      final service = DailyQuestService();
      service.register('win_3', 3);

      service.incrementProgress('win_3', 1);
      service.incrementProgress('win_3', 1);

      expect(service.progressOf('win_3'), 2);
      expect(service.isCompleted('win_3'), isFalse);
    });

    test('đạt đủ target thì isCompleted true, vượt target không lỗi', () {
      final service = DailyQuestService();
      service.register('win_3', 3);

      service.incrementProgress('win_3', 3);
      expect(service.isCompleted('win_3'), isTrue);

      expect(
        () => service.incrementProgress('win_3', 100),
        returnsNormally,
      );
      expect(service.isCompleted('win_3'), isTrue);
    });

    test('progress overflow gần int.max thì throw RangeError', () {
      final service = DailyQuestService();
      service.register('overflow', 1);
      service.incrementProgress('overflow', 0x7FFFFFFFFFFFFFFF - 1);

      expect(
        () => service.incrementProgress('overflow', 2),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('DailyQuestService: claim', () {
    test('claim quest chưa hoàn thành trả về false, không throw', () {
      final service = DailyQuestService();
      service.register('win_3', 3);
      service.incrementProgress('win_3', 1);

      expect(service.claim('win_3'), isFalse);
      expect(service.isClaimed('win_3'), isFalse);
    });

    test('claim quest chưa register trả về false, không throw', () {
      final service = DailyQuestService();
      expect(service.claim('unknown'), isFalse);
    });

    test('claim quest đã hoàn thành trả về true đúng 1 lần, lần 2 trả false', () {
      final service = DailyQuestService();
      service.register('win_3', 3);
      service.incrementProgress('win_3', 3);

      expect(service.claim('win_3'), isTrue);
      expect(service.isClaimed('win_3'), isTrue);
      expect(service.claim('win_3'), isFalse);
    });
  });

  group('DailyQuestService: reset theo period', () {
    test('quest daily: sang ngày mới thì progress/claimed reset về 0/false', () async {
      await setDay(_realDay);
      final service = DailyQuestService();
      service.register('win_3', 3, period: QuestPeriod.daily);
      service.incrementProgress('win_3', 3);
      expect(service.claim('win_3'), isTrue);

      await setDay(_realDay + 1);

      expect(service.progressOf('win_3'), 0);
      expect(service.isCompleted('win_3'), isFalse);
      expect(service.isClaimed('win_3'), isFalse);
    });

    test(
      'quest daily: increment sau khi rollover bắt đầu lại từ 0 (không cộng dồn lên số cũ)',
      () async {
        await setDay(_realDay);
        final service = DailyQuestService();
        service.register('win_3', 3, period: QuestPeriod.daily);
        service.incrementProgress('win_3', 2);

        await setDay(_realDay + 1);
        service.incrementProgress('win_3', 1);

        expect(service.progressOf('win_3'), 1);
      },
    );

    test('quest weekly: sang ngày kế tiếp trong cùng tuần KHÔNG reset', () async {
      // Đầu tuần KẾ TIẾP (luôn > _realDay, xem doc `setDay`), để mọi ngày
      // trong test này đều thoả bất biến "mốc set >= ngày thật".
      final weekStart = ((_realDay ~/ 7) + 1) * 7;
      await setDay(weekStart);
      final service = DailyQuestService();
      service.register('use_booster', 1, period: QuestPeriod.weekly);
      service.incrementProgress('use_booster', 1);
      expect(service.claim('use_booster'), isTrue);

      await setDay(weekStart + 1);

      expect(service.progressOf('use_booster'), 1);
      expect(service.isClaimed('use_booster'), isTrue);
    });

    test('quest weekly: sang tuần kế tiếp thì reset progress/claimed', () async {
      final weekStart = ((_realDay ~/ 7) + 1) * 7;
      await setDay(weekStart);
      final service = DailyQuestService();
      service.register('use_booster', 1, period: QuestPeriod.weekly);
      service.incrementProgress('use_booster', 1);
      expect(service.claim('use_booster'), isTrue);

      await setDay(weekStart + 7);

      expect(service.progressOf('use_booster'), 0);
      expect(service.isClaimed('use_booster'), isFalse);
    });

    test(
      'daily và weekly quest độc lập nhau: reset ngày không đụng weekly chưa hết tuần',
      () async {
        final weekStart = ((_realDay ~/ 7) + 1) * 7;
        await setDay(weekStart);
        final service = DailyQuestService();
        service.register('daily_q', 1, period: QuestPeriod.daily);
        service.register('weekly_q', 1, period: QuestPeriod.weekly);
        service.incrementProgress('daily_q', 1);
        service.incrementProgress('weekly_q', 1);

        await setDay(weekStart + 1);

        expect(service.progressOf('daily_q'), 0);
        expect(service.progressOf('weekly_q'), 1);
      },
    );

    test(
      'quest register SAU KHI period đã đổi (late registration) vẫn coi là chưa bắt đầu, không kế thừa record cũ của id khác',
      () async {
        await setDay(_realDay);
        final early = DailyQuestService();
        early.register('will_reuse_id', 1);
        early.incrementProgress('will_reuse_id', 1);
        early.claim('will_reuse_id');

        await setDay(_realDay + 1);
        // Instance mới, register muộn sau khi ngày đã đổi.
        final late_ = DailyQuestService();
        late_.register('will_reuse_id', 1);

        expect(late_.progressOf('will_reuse_id'), 0);
        expect(late_.isClaimed('will_reuse_id'), isFalse);
      },
    );
  });

  group('DailyQuestService: corrupt/persist', () {
    test('drops corrupt record entries instead of crashing hydration', () async {
      // periodKey khớp đúng ngày thật (không setDay) — chỉ "good" phải sống
      // sót qua bước reset-theo-period, các entry lỗi khác phải bị loại bỏ
      // ngay ở bước parse JSON, trước cả khi so periodKey.
      await storage.setString(
        'daily_quest_progress_v1',
        '{"good":{"periodKey":$_realDay,"progress":2,"claimed":false},'
        '"wrongShape":"3",'
        '"negativeProgress":{"periodKey":$_realDay,"progress":-1,"claimed":false},'
        '"wrongTypes":{"periodKey":"x","progress":1,"claimed":false},'
        '"":{"periodKey":$_realDay,"progress":1,"claimed":false},'
        '"schemaVersion":1}',
      );
      final service = DailyQuestService();
      service.register('good', 3);
      service.register('wrongShape', 3);
      service.register('negativeProgress', 3);
      service.register('wrongTypes', 3);

      expect(service.progressOf('good'), 2);
      expect(service.progressOf('wrongShape'), 0);
      expect(service.progressOf('negativeProgress'), 0);
      expect(service.progressOf('wrongTypes'), 0);
    });

    test(
      'reload từ instance mới đọc lại đúng progress/claimed đã lưu (cùng period)',
      () async {
        await setDay(_realDay);
        final service = DailyQuestService();
        service.register('win_3', 3);
        service.incrementProgress('win_3', 3);
        service.claim('win_3');

        await service.debugPendingSaves;

        final reloaded = DailyQuestService();
        reloaded.register('win_3', 3);
        expect(reloaded.progressOf('win_3'), 3);
        expect(reloaded.isClaimed('win_3'), isTrue);
      },
    );

    test(
      'burst nhiều incrementProgress liên tiếp không await giữa các lần vẫn ghi đúng thứ tự cuối cùng xuống disk',
      () async {
        await setDay(_realDay);
        final service = DailyQuestService();
        service.register('combo', 100);

        for (var i = 0; i < 10; i++) {
          service.incrementProgress('combo', 1);
        }

        await service.debugPendingSaves;

        final reloaded = DailyQuestService();
        reloaded.register('combo', 100);
        expect(reloaded.progressOf('combo'), 10);
      },
    );

    group('ENH-71: storageKey tuỳ chỉnh', () {
      test('không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ', () async {
        final service = DailyQuestService();
        service.register('wins', 3);
        service.incrementProgress('wins', 1);
        await service.debugPendingSaves;

        expect(storage.getString('daily_quest_progress_v1'), isNotNull);
      });

      test('2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau', () async {
        final a = DailyQuestService(storageKey: 'quest_a');
        final b = DailyQuestService(storageKey: 'quest_b');
        a.register('wins', 3);
        b.register('wins', 3);

        a.incrementProgress('wins', 1);
        b.incrementProgress('wins', 2);
        await a.debugPendingSaves;
        await b.debugPendingSaves;

        expect(a.progressOf('wins'), 1);
        expect(b.progressOf('wins'), 2);
      });

      test('storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới đọc lại đúng)', () async {
        final service = DailyQuestService(storageKey: 'quest_custom');
        service.register('wins', 3);
        service.incrementProgress('wins', 2);
        await service.debugPendingSaves;

        final restarted = DailyQuestService(storageKey: 'quest_custom');
        restarted.register('wins', 3);
        expect(restarted.progressOf('wins'), 2);
      });

      test('không đổi hành vi register/incrementProgress/claim hiện có khi dùng storageKey tuỳ chỉnh', () {
        final service = DailyQuestService(storageKey: 'k');
        service.register('wins', 1);
        service.incrementProgress('wins', 1);

        expect(service.isCompleted('wins'), isTrue);
        expect(service.claim('wins'), isTrue);
        expect(service.isClaimed('wins'), isTrue);
      });
    });
  });

  group('ENH-76: progressRatio', () {
    test('chưa từng register: trả 0.0, không throw', () {
      final service = DailyQuestService();
      expect(() => service.progressRatio('unknown'), returnsNormally);
      expect(service.progressRatio('unknown'), 0.0);
    });

    test('đã register nhưng chưa incrementProgress: trả 0.0', () {
      final service = DailyQuestService();
      service.register('wins', 10);
      expect(service.progressRatio('wins'), 0.0);
    });

    test('progress ở giữa target: trả đúng tỉ lệ', () {
      final service = DailyQuestService();
      service.register('wins', 10);
      service.incrementProgress('wins', 3);
      expect(service.progressRatio('wins'), 0.3);
    });

    test('progress vượt target: clamp đúng 1.0, không vượt quá', () {
      final service = DailyQuestService();
      service.register('wins', 10);
      service.incrementProgress('wins', 15);
      expect(service.progressRatio('wins'), 1.0);
    });

    test('progress đúng bằng target: trả đúng 1.0', () {
      final service = DailyQuestService();
      service.register('wins', 10);
      service.incrementProgress('wins', 10);
      expect(service.progressRatio('wins'), 1.0);
    });
  });
}
