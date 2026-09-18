import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/persistent_cooldown_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('PersistentCooldownService: accessor', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(PersistentCooldownService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = PersistentCooldownService();
      Get.put(service, permanent: true);
      expect(PersistentCooldownService.maybe, same(service));
    });
  });

  group('PersistentCooldownService: validate input', () {
    test('start với key rỗng throw ArgumentError', () {
      final service = PersistentCooldownService();
      expect(
        () => service.start('', const Duration(seconds: 10)),
        throwsArgumentError,
      );
    });

    test('start với duration <= 0 throw ArgumentError', () {
      final service = PersistentCooldownService();
      expect(() => service.start('k', Duration.zero), throwsArgumentError);
      expect(
        () => service.start('k', const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });

  group('PersistentCooldownService: start/read/cancel/restart', () {
    test('key chưa từng start: ready, remaining = 0', () {
      final service = PersistentCooldownService();
      expect(service.statusOf('never'), CooldownStatus.ready);
      expect(service.remainingOf('never'), Duration.zero);
    });

    test('start xong: running, remaining ~ đúng duration đã set', () {
      final service = PersistentCooldownService();
      service.start('booster', const Duration(seconds: 10));

      expect(service.statusOf('booster'), CooldownStatus.running);
      final remaining = service.remainingOf('booster');
      expect(remaining.inMilliseconds, greaterThan(9900));
      expect(remaining.inMilliseconds, lessThanOrEqualTo(10000));
    });

    test('mô phỏng trôi qua 5s (chưa hết cooldown 10s): còn ~5s, vẫn running', () {
      final service = PersistentCooldownService();
      service.start('booster', const Duration(seconds: 10));

      store.setInt(StorageKeys.maxMsSeen, _realMs + 5000);

      expect(service.statusOf('booster'), CooldownStatus.running);
      final remaining = service.remainingOf('booster');
      expect(remaining.inMilliseconds, greaterThan(4900));
      expect(remaining.inMilliseconds, lessThanOrEqualTo(5000));
    });

    test('mô phỏng trôi qua đủ 10s: ready, remaining = 0', () {
      final service = PersistentCooldownService();
      service.start('booster', const Duration(seconds: 10));

      store.setInt(StorageKeys.maxMsSeen, _realMs + 10000);

      expect(service.statusOf('booster'), CooldownStatus.ready);
      expect(service.remainingOf('booster'), Duration.zero);
    });

    test('cancel một cooldown đang chạy: ready ngay lập tức', () {
      final service = PersistentCooldownService();
      service.start('booster', const Duration(seconds: 10));
      service.cancel('booster');

      expect(service.statusOf('booster'), CooldownStatus.ready);
    });

    test('cancel key chưa từng tồn tại: không throw, vẫn ready', () {
      final service = PersistentCooldownService();
      expect(() => service.cancel('không tồn tại'), returnsNormally);
      expect(service.statusOf('không tồn tại'), CooldownStatus.ready);
    });

    test('restart (start lại key đang chạy): reset về đúng duration mới', () {
      final service = PersistentCooldownService();
      service.start('booster', const Duration(seconds: 10));
      store.setInt(StorageKeys.maxMsSeen, _realMs + 8000);
      expect(service.remainingOf('booster').inMilliseconds, lessThan(3000));

      service.start('booster', const Duration(seconds: 20));

      final remaining = service.remainingOf('booster');
      expect(remaining.inMilliseconds, greaterThan(19000));
    });

    test('nhiều key độc lập nhau, không đụng lẫn nhau', () {
      final service = PersistentCooldownService();
      service.start('a', const Duration(seconds: 10));
      service.start('b', const Duration(seconds: 100));

      service.cancel('a');

      expect(service.statusOf('a'), CooldownStatus.ready);
      expect(service.statusOf('b'), CooldownStatus.running);
    });
  });

  group('PersistentCooldownService: sống qua "restart" app', () {
    test('instance mới đọc từ cùng SharedPreferences vẫn thấy đúng state', () async {
      final service1 = PersistentCooldownService();
      service1.start('booster', const Duration(seconds: 10));

      final service2 = PersistentCooldownService();
      expect(service2.statusOf('booster'), CooldownStatus.running);
      final remaining = service2.remainingOf('booster');
      expect(remaining.inMilliseconds, greaterThan(9000));
    });
  });

  group('PersistentCooldownService: corrupt save không mở khóa sớm', () {
    test('JSON hỏng hoàn toàn ở top-level: coi như rỗng, mọi key đều ready', () async {
      await store.setString(StorageKeys.cooldownStateV1, 'not valid json {{{');
      final service = PersistentCooldownService();

      expect(service.statusOf('anything'), CooldownStatus.ready);
      expect(() => service.start('anything', const Duration(seconds: 5)), returnsNormally);
    });

    test('1 entry sai kiểu dữ liệu bị bỏ qua, các key hợp lệ khác không bị ảnh hưởng', () async {
      final service = PersistentCooldownService();
      service.start('valid', const Duration(seconds: 10));

      // Cố tình chèn thêm 1 entry sai kiểu (value là String thay vì int)
      // thẳng vào blob đã lưu, mô phỏng save bị hỏng/tay chỉnh.
      final raw = store.getString(StorageKeys.cooldownStateV1)!;
      final patched = '${raw.substring(0, raw.length - 1)},"corrupt":"abc"}';
      await store.setString(StorageKeys.cooldownStateV1, patched);

      final service2 = PersistentCooldownService();
      expect(service2.statusOf('valid'), CooldownStatus.running);
      expect(
        service2.statusOf('corrupt'),
        CooldownStatus.ready,
        reason: 'entry sai kiểu bị bỏ qua, không được coi là running lẫn unlock sớm nghĩa khác',
      );
    });
  });

  group('PersistentCooldownService: cleanup expired entries', () {
    test('entry đã hết hạn bị dọn khỏi storage sau lần start/cancel kế tiếp', () async {
      final service = PersistentCooldownService();
      service.start('expired', const Duration(seconds: 5));
      store.setInt(StorageKeys.maxMsSeen, _realMs + 5000);

      service.start('other', const Duration(seconds: 10));

      final raw = store.getString(StorageKeys.cooldownStateV1)!;
      expect(raw, isNot(contains('expired')));
      expect(raw, contains('other'));
    });
  });

  group('PersistentCooldownService: reactive revision', () {
    test('revision tăng khi start/cancel, không tự tăng theo thời gian trôi qua', () {
      final service = PersistentCooldownService();
      final before = service.revision.value;

      service.start('booster', const Duration(seconds: 10));
      expect(service.revision.value, greaterThan(before));

      final afterStart = service.revision.value;
      store.setInt(StorageKeys.maxMsSeen, _realMs + 5000);
      expect(
        service.revision.value,
        afterStart,
        reason: 'không có timer nào tự bump revision theo thời gian',
      );

      service.cancel('booster');
      expect(service.revision.value, greaterThan(afterStart));
    });
  });
}
