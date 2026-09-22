import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

/// Pauses `setString` until [gate] resolves — same technique used in
/// `season_event_service_test.dart`/`save_slot_manager_test.dart` for
/// BUG-45: a tight synchronous burst (no real gap between calls) does NOT
/// reproduce this kind of race at all with the in-memory storage these
/// tests use, since `await` on an already-complete Future can resolve
/// without a microtask hop.
class _GatedStorageService extends StorageService {
  _GatedStorageService(super.prefs);
  Completer<void>? gate;

  @override
  Future<void> setString(String key, String value) async {
    final g = gate;
    if (g != null) await g.future;
    return super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('EnergyService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(EnergyService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = EnergyService();
      Get.put(service, permanent: true);
      expect(EnergyService.maybe, same(service));
    });

    test('mặc định đầy tim khi chưa có gì lưu trước đó', () {
      final service = EnergyService(maxEnergy: 5);
      expect(service.currentEnergy, 5);
    });

    test('consumeEnergy trừ đúng số lượng và trả về true khi đủ tim', () {
      final service = EnergyService(maxEnergy: 5);

      expect(service.consumeEnergy(), true);
      expect(service.currentEnergy, 4);

      expect(service.consumeEnergy(2), true);
      expect(service.currentEnergy, 2);
    });

    test('consumeEnergy trả về false và KHÔNG trừ khi không đủ tim', () {
      final service = EnergyService(maxEnergy: 3);

      expect(service.consumeEnergy(3), true);
      expect(service.currentEnergy, 0);

      expect(service.consumeEnergy(1), false);
      expect(service.currentEnergy, 0, reason: 'không đủ thì không được trừ');
    });

    test('tim tự hồi đúng số lượng sau khi mô phỏng trôi qua N phút', () {
      final service = EnergyService(
        maxEnergy: 5,
        refillInterval: const Duration(minutes: 30),
      );

      // Trừ 3 tim -> baseline hồi tim bắt đầu tính từ đây.
      expect(service.consumeEnergy(3), true);
      expect(service.currentEnergy, 2);

      // Mô phỏng "đóng app -> mở lại sau 30 phút" bằng cách đẩy mốc
      // nowMsClamped() đọc/kẹp vào (StorageKeys.maxMsSeen) tiến lên, thay vì
      // chờ Future.delayed thật.
      store.setInt(StorageKeys.maxMsSeen, _realMs + 30 * 60 * 1000);
      expect(service.currentEnergy, 3, reason: 'hồi đúng 1 tim sau 30 phút');

      // Tiến thêm 65 phút nữa (tổng ~95 phút từ lúc trừ tim) -> hồi thêm 2
      // tim nữa (3 tick trọn vẹn), tổng phải đầy lại (max = 5), không vượt.
      store.setInt(StorageKeys.maxMsSeen, _realMs + 95 * 60 * 1000);
      expect(service.currentEnergy, 5, reason: 'hồi đủ và không vượt max');
    });

    test(
      'chỉnh lùi mốc thời gian trực tiếp không làm tim tụt lại hay tăng khống',
      () {
        final service = EnergyService(
          maxEnergy: 5,
          refillInterval: const Duration(minutes: 30),
        );

        expect(service.consumeEnergy(2), true);
        store.setInt(StorageKeys.maxMsSeen, _realMs + 30 * 60 * 1000);
        expect(service.currentEnergy, 4);

        // Cố tình ghi thẳng một mốc "quá khứ" vào StorageKeys.maxMsSeen để mô
        // phỏng hành vi chỉnh lùi đồng hồ máy. nowMsClamped() tự kẹp lại theo
        // mốc lớn nhất từng thấy nên không farm thêm được tim.
        store.setInt(StorageKeys.maxMsSeen, _realMs - 999999999);
        expect(
          service.currentEnergy,
          4,
          reason: 'không được tụt lại và cũng không được hồi thêm khống',
        );
      },
    );

    test(
      'grantInfiniteLives: consumeEnergy luôn thành công và không trừ tim',
      () {
        final service = EnergyService(maxEnergy: 3);
        expect(service.consumeEnergy(3), true);
        expect(service.currentEnergy, 0);

        service.grantInfiniteLives(const Duration(minutes: 10));
        expect(service.hasInfiniteLives, true);

        expect(service.consumeEnergy(1), true);
        expect(
          service.currentEnergy,
          0,
          reason:
              'infinite lives không cộng dồn tim, chỉ cho phép tiêu thoải mái',
        );
      },
    );

    test('grantInfiniteLives hết hạn thì lại trừ tim bình thường', () {
      final service = EnergyService(maxEnergy: 3);
      service.grantInfiniteLives(const Duration(minutes: 10));
      expect(service.hasInfiniteLives, true);

      store.setInt(StorageKeys.maxMsSeen, _realMs + 11 * 60 * 1000);
      expect(service.hasInfiniteLives, false);

      expect(service.consumeEnergy(3), true);
      expect(
        service.consumeEnergy(1),
        false,
        reason: 'hết hạn rồi thì hết tim là thua',
      );
    });

    group('BUG-52: grantInfiniteLives cộng dồn, không ghi đè', () {
      test(
        'grant lần 2 (duration ngắn hơn thời gian còn lại của lần 1) '
        'KHÔNG rút ngắn mốc hết hạn',
        () async {
          final service = EnergyService(maxEnergy: 3);

          await service.grantInfiniteLives(const Duration(hours: 1));
          final untilAfterFirst = store.getInt(
            StorageKeys.energyInfiniteUntilMs,
          );

          await service.grantInfiniteLives(const Duration(minutes: 5));
          final untilAfterSecond = store.getInt(
            StorageKeys.energyInfiniteUntilMs,
          );

          expect(
            untilAfterSecond,
            untilAfterFirst,
            reason:
                'lần 2 ngắn hơn thời gian còn lại của lần 1 -> giữ nguyên '
                'mốc dài hơn, không bị ghi đè xuống ngắn hơn',
          );
          expect(service.hasInfiniteLives, true);
        },
      );

      test(
        'grant lần 2 (duration dài hơn thời gian còn lại của lần 1) '
        'kéo dài thêm đúng mốc mới',
        () async {
          final service = EnergyService(maxEnergy: 3);

          await service.grantInfiniteLives(const Duration(minutes: 5));
          await service.grantInfiniteLives(const Duration(hours: 2));

          final until = store.getInt(StorageKeys.energyInfiniteUntilMs);
          expect(
            until,
            greaterThanOrEqualTo(_realMs + const Duration(hours: 2).inMilliseconds),
          );
        },
      );

      test('grant lần đầu (chưa có mốc trước đó) hoạt động đúng như cũ', () async {
        final service = EnergyService(maxEnergy: 3);

        await service.grantInfiniteLives(const Duration(minutes: 10));

        expect(service.hasInfiniteLives, true);
        expect(
          store.getInt(StorageKeys.energyInfiniteUntilMs),
          greaterThanOrEqualTo(_realMs + const Duration(minutes: 10).inMilliseconds),
        );
      });
    });

    test('timeUntilNextEnergy trả về Duration.zero khi đã đầy tim', () {
      final service = EnergyService(maxEnergy: 5);
      expect(service.timeUntilNextEnergy, Duration.zero);
    });

    test(
      'timeUntilNextEnergy trả về Duration.zero khi đang có infinite lives',
      () {
        final service = EnergyService(maxEnergy: 3);
        expect(service.consumeEnergy(3), true);
        service.grantInfiniteLives(const Duration(minutes: 10));
        expect(service.timeUntilNextEnergy, Duration.zero);
      },
    );

    test('timeUntilNextEnergy đếm ngược đúng khi tim chưa đầy', () {
      final service = EnergyService(
        maxEnergy: 5,
        refillInterval: const Duration(minutes: 30),
      );

      // Đầy tim trước khi trừ -> baseline hồi tim = đúng thời điểm
      // consumeEnergy() chạy, đọc thẳng từ storage để tránh lệch vài ms so
      // với đồng hồ thật lúc test tiếp tục chạy sau đó.
      expect(service.consumeEnergy(2), true);
      final baseline = service.debugLastRegenMs;

      // Tiến đúng 10 phút kể từ baseline (không phải từ "bây giờ" của đồng
      // hồ thật, để phép so sánh Duration bên dưới chính xác tuyệt đối).
      store.setInt(StorageKeys.maxMsSeen, baseline + 10 * 60 * 1000);
      expect(service.timeUntilNextEnergy, const Duration(minutes: 20));

      // Tiến đúng tới mốc tick tiếp theo (30 phút kể từ baseline) -> tim vừa
      // hồi lên 4 (3 + 1 tick), đếm ngược bắt đầu lại nguyên 1 chu kỳ mới
      // (30 phút).
      store.setInt(StorageKeys.maxMsSeen, baseline + 30 * 60 * 1000);
      expect(service.currentEnergy, 4);
      expect(service.timeUntilNextEnergy, const Duration(minutes: 30));
    });

    group('BUG-19: validate input, chuẩn hoá giá trị lưu, ghi atomic', () {
      test('constructor throw khi maxEnergy <= 0', () {
        expect(() => EnergyService(maxEnergy: 0), throwsArgumentError);
        expect(() => EnergyService(maxEnergy: -1), throwsArgumentError);
      });

      test('constructor throw khi refillInterval <= Duration.zero', () {
        expect(
          () => EnergyService(refillInterval: Duration.zero),
          throwsArgumentError,
        );
        expect(
          () => EnergyService(refillInterval: const Duration(seconds: -1)),
          throwsArgumentError,
        );
      });

      test(
        'consumeEnergy(0) throw ArgumentError, không âm thầm "thành công"',
        () {
          final service = EnergyService(maxEnergy: 5);
          expect(() => service.consumeEnergy(0), throwsArgumentError);
          // Không có gì bị trừ.
          expect(service.currentEnergy, 5);
        },
      );

      test(
        'consumeEnergy(số âm) throw ArgumentError, không cộng nhầm năng lượng',
        () {
          final service = EnergyService(maxEnergy: 5);
          expect(() => service.consumeEnergy(-2), throwsArgumentError);
          expect(service.currentEnergy, 5);
        },
      );

      test('giá trị energy lưu trữ bị hỏng (âm hoặc vượt maxEnergy) được clamp '
          'lại đúng khi đọc, không tin tưởng nguyên vẹn', () async {
        // Mô phỏng save bị chỉnh tay/import lỗi: count vượt maxEnergy.
        await store.setString(
          StorageKeys.energyStateV1,
          '{"count": 999, "lastMs": $_realMs}',
        );
        final service = EnergyService(maxEnergy: 5);
        expect(service.currentEnergy, 5);
      });

      test('giá trị energy âm trong storage được clamp về 0 khi đọc', () async {
        await store.setString(
          StorageKeys.energyStateV1,
          '{"count": -7, "lastMs": $_realMs}',
        );
        final service = EnergyService(maxEnergy: 5);
        expect(service.currentEnergy, 0);
      });

      test('save cũ theo format 2-key (trước BUG-19) vẫn đọc được đúng — '
          'migrate ngầm, không reset về đầy tim', () async {
        // Format cũ: 2 key riêng, chưa có energyStateV1.
        await store.setInt(StorageKeys.energyCount, 3);
        await store.setInt(StorageKeys.energyLastMs, _realMs);

        final service = EnergyService(maxEnergy: 5);
        expect(service.currentEnergy, 3);
      });

      test('JSON hỏng trong energyStateV1 không crash, fallback về format cũ '
          'hoặc mặc định đầy tim', () async {
        await store.setString(StorageKeys.energyStateV1, 'not valid json{{{');
        final service = EnergyService(maxEnergy: 5);
        expect(service.currentEnergy, 5);
        expect(() => service.currentEnergy, returnsNormally);
      });

      test('consumeEnergy() ghi count + lastMs bằng đúng 1 lần write (atomic) '
          'thay vì 2 write rời rạc', () {
        final service = EnergyService(maxEnergy: 5);
        // "Làm nóng" watermark của nowMsClamped() trước — lần đầu tiên nó
        // được gọi trong 1 test luôn tự thêm 1 write phụ (nâng
        // StorageKeys.maxMsSeen), không liên quan tới tính atomic đang
        // test ở đây. Đọc currentEnergy 1 lần để watermark đã ổn định.
        service.currentEnergy;
        final writesBefore = store.platformWrites;

        service.consumeEnergy(1);

        // Trước BUG-19: 2 write rời (energyCount + energyLastMs). Sau
        // fix: 1 write duy nhất (energyStateV1, 1 chuỗi JSON gộp cả 2).
        expect(store.platformWrites - writesBefore, 1);
      });

      test('sau khi ghi atomic, đọc lại qua instance mới vẫn đúng cả count lẫn '
          'baseline thời gian', () {
        final service1 = EnergyService(maxEnergy: 5);
        service1.consumeEnergy(2);
        final baselineAfterSpend = service1.debugLastRegenMs;

        final service2 = EnergyService(maxEnergy: 5);
        expect(service2.currentEnergy, 3);
        expect(service2.debugLastRegenMs, baselineAfterSpend);
      });
    });

    group('BUG-46: save race khi consumeEnergy()/_regen() chồng lấn', () {
      test(
        '2 lần consumeEnergy() liên tiếp, lần đầu vẫn đang ghi thật (Completer '
        'chưa complete): sau khi settle, count đúng đã trừ CẢ 2 lần, không '
        'bị lần ghi sau đè ngược (double-tap không farm được năng lượng)',
        () async {
          final gated = _GatedStorageService(await SharedPreferences.getInstance());
          Get.put<StorageService>(gated, permanent: true);
          final service = EnergyService(maxEnergy: 5);
          expect(service.currentEnergy, 5);

          gated.gate = Completer<void>();
          final first = service.consumeEnergy(1); // count 5 -> 4, ghi bị chặn
          final second = service.consumeEnergy(1); // count 4 -> 3, phải queue

          expect(first, isTrue);
          expect(second, isTrue);
          expect(service.currentEnergy, 3); // in-memory đã đúng ngay lập tức

          gated.gate!.complete();
          await service.debugPendingSaves;

          final restarted = EnergyService(maxEnergy: 5);
          expect(restarted.currentEnergy, 3); // không rollback về 4
        },
      );

      test(
        '_regen() đang ghi (Completer chưa complete) rồi consumeEnergy() gọi '
        'ngay sau: write CUỐI CÙNG (của consumeEnergy, theo đúng thứ tự gọi) '
        'không bị mất — state cuối phản ánh đúng logic mới nhất',
        () async {
          final gated = _GatedStorageService(await SharedPreferences.getInstance());
          Get.put<StorageService>(gated, permanent: true);
          await gated.setInt(StorageKeys.maxMsSeen, _realMs);
          final service = EnergyService(
            maxEnergy: 5,
            refillInterval: const Duration(minutes: 30),
          );
          service.consumeEnergy(2); // count 5 -> 3, chờ settle write đầu.
          await service.debugPendingSaves;

          // Qua đúng 1 chu kỳ refill -> _regen() sẽ credit +1 khi tính lại.
          await gated.setInt(
            StorageKeys.maxMsSeen,
            _realMs + const Duration(minutes: 30).inMilliseconds,
          );

          gated.gate = Completer<void>();
          // Trigger _regen() qua currentEnergy — write (count 3 -> 4) bị
          // chặn bởi gate, coi như đang "in flight" thật sự.
          service.currentEnergy;

          // Gọi consumeEnergy ngay sau, trong lúc write regen còn treo —
          // đúng kịch bản race. _currentState() của lần gọi này đọc qua
          // `_latestState` (giá trị regen VỪA schedule, count=4) — không
          // phải storage cũ (count=3, chưa land) — nên trừ đúng từ 4.
          final consumed = service.consumeEnergy(1);
          expect(consumed, isTrue);

          gated.gate!.complete();
          await service.debugPendingSaves;

          // consumeEnergy() giờ đọc qua `_currentState()` (ưu tiên
          // `_latestState` trong bộ nhớ — giá trị regen VỪA schedule,
          // dù chưa land disk) thay vì đọc thẳng storage cũ — nên trừ
          // đúng từ 4 (3 + 1 regen), ra 3, không phải từ 3 cũ (thiếu mất
          // phần regen vừa tính). Cả 2 thay đổi (regen +1, consume -1)
          // đều phản ánh đúng, không cái nào bị mất.
          final restarted = EnergyService(
            maxEnergy: 5,
            refillInterval: const Duration(minutes: 30),
          );
          expect(restarted.currentEnergy, 3);
        },
      );

      test(
        'hành vi trả về (count sau consumeEnergy) không đổi khi không có race',
        () {
          final service = EnergyService(maxEnergy: 5);
          expect(service.consumeEnergy(2), isTrue);
          expect(service.currentEnergy, 3);
          expect(service.consumeEnergy(10), isFalse);
          expect(service.currentEnergy, 3); // không đổi khi fail
        },
      );
    });
  });
}
